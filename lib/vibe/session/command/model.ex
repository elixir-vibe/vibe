defmodule Vibe.Session.Command.Model do
  @moduledoc "Slash command: /model — switch the active model."
  @behaviour Vibe.Session.Command.Command
  alias Vibe.Session.Command.Spec

  @impl true
  def spec, do: %Spec{name: "model", description: "Choose model", selectors: []}

  @impl true
  def run(args, _session_state) when is_binary(args) do
    case String.trim(args) do
      "" ->
        {:command, :open_model_selector}

      input ->
        case Vibe.Model.Resolver.resolve(input) do
          {:ok, model, nil} ->
            {:command, {:select_model, %{model: model}}}

          {:ok, model, effort} ->
            {:events,
             [
               Vibe.Event.new(:model_selected, "", Vibe.Event.Model.selected(model)),
               Vibe.Event.new(:effort_selected, "", Vibe.Event.Model.effort_selected(effort))
             ]}

          {:error, :not_found} ->
            {:command, {:select_model, %{model: input}}}
        end
    end
  end
end
