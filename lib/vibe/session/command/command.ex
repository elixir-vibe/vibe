defmodule Vibe.Session.Command.Command do
  @moduledoc "Slash command: /command — run a shell command."
  alias Vibe.Event

  @type spec ::
          Vibe.Session.Command.Spec.t()
          | %{
              required(:name) => String.t(),
              optional(:aliases) => [String.t()],
              optional(:description) => String.t(),
              optional(:selectors) => [atom()]
            }

  @type result ::
          {:events, [Event.t()]} | {:command, atom() | {atom(), map()}} | :compact | :ignore

  @callback spec() :: spec()
  @callback run(String.t(), map()) :: result()
  @callback selector_action(term(), map()) :: result() | {:command, String.t()}

  @optional_callbacks selector_action: 2
end
