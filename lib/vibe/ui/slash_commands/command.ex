defmodule Vibe.UI.SlashCommands.Command do
  @moduledoc "Slash command: /command — run a shell command."
  alias Vibe.UI.Event
  alias Vibe.UI.State

  @type spec ::
          Vibe.UI.SlashCommands.Spec.t()
          | %{
              required(:name) => String.t(),
              optional(:aliases) => [String.t()],
              optional(:description) => String.t(),
              optional(:selectors) => [atom()]
            }

  @type result ::
          {:events, [Event.t()]} | {:command, atom() | {atom(), map()}} | :compact | :ignore

  @callback spec() :: spec()
  @callback run(String.t(), State.t()) :: result()
  @callback selector_action(term(), State.t()) :: result() | {:command, String.t()}

  @optional_callbacks selector_action: 2
end
