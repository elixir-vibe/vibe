defmodule Vibe.Session.Command.Effort do
  @moduledoc "Slash command: /effort — set reasoning effort level."
  @behaviour Vibe.Session.Command.Command
  alias Vibe.Session.Command.Spec

  alias Vibe.Model.Effort

  @impl true
  def spec, do: %Spec{name: "effort", description: "Choose effort", selectors: []}

  @impl true
  def run(args, _session_state) when is_binary(args) do
    case String.trim(args) do
      "" ->
        {:command, :open_effort_selector}

      value ->
        case Effort.from_string(value) do
          {:ok, effort} ->
            {:command, {:select_effort, %{effort: effort}}}

          {:error, {:unknown_effort, value}} ->
            {:command,
             {:notification_added, %{level: :warning, text: "unknown effort: #{value}"}}}
        end
    end
  end
end
