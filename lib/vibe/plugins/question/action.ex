defmodule Vibe.Plugins.Question.Action do
  @moduledoc "Model-facing action: ask the user a question with selectable options."
  import JSONSpec

  @schema schema(
            %{
              required(:question) => String.t(),
              required(:options) => [
                %{
                  required(:label) => String.t(),
                  optional(:description) => String.t()
                }
              ]
            },
            doc: [
              question: "The question to ask the user",
              options: "Options for the user to choose from"
            ]
          )

  @user_response_timeout_ms 300_000

  use Jido.Action,
    name: "question",
    description:
      "Ask the user a question and let them pick from options. Use when you need user input to proceed.",
    schema: @schema

  @impl true
  def run(params, context) do
    Vibe.Actions.ToolResult.run(fn ->
      params = JSONSpec.atomize(@schema, params)
      session_id = session_id(context)
      labels = Enum.map(params.options, & &1.label)

      case ask_user(session_id, params.question, labels) do
        {:ok, answer} ->
          {:ok, "User selected: #{answer}"}

        {:error, :cancelled} ->
          {:ok, "User cancelled the selection"}

        {:error, :no_session} ->
          {:ok, %{error: "UI not available (running in non-interactive mode)"}}
      end
    end)
  end

  defp ask_user(nil, _question, _options), do: {:error, :no_session}

  defp ask_user(session_id, question, options) do
    with {:ok, session} <- Vibe.Session.lookup(session_id) do
      Vibe.Plugins.Question.register_waiter(session_id, self())

      selector = %{
        kind: :question_selector,
        title: question,
        items: options,
        selected: 0,
        limit: length(options)
      }

      Vibe.Session.emit_transient_event(
        session,
        Vibe.UI.Event.new(:selector_opened, session_id, selector)
      )

      receive do
        {:question_answered, answer} -> {:ok, answer}
        {:question_cancelled} -> {:error, :cancelled}
      after
        @user_response_timeout_ms ->
          Vibe.Plugins.Question.unregister_waiter(session_id)
          {:error, :cancelled}
      end
    end
  end

  defp session_id(context) when is_map(context), do: Map.get(context, :session_id)
  defp session_id(_context), do: nil
end
