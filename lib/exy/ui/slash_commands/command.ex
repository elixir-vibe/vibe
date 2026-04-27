defmodule Exy.UI.SlashCommands.Command do
  @moduledoc false

  alias Exy.UI.Event
  alias Exy.UI.State

  @type spec :: %{
          required(:name) => String.t(),
          optional(:aliases) => [String.t()],
          optional(:description) => String.t(),
          optional(:selectors) => [atom()]
        }

  @type result :: {:events, [Event.t()]} | :compact | :ignore

  @callback spec() :: spec()
  @callback run(String.t(), State.t()) :: result()
  @callback selector_action(term(), State.t()) :: result() | {:command, String.t()}

  @optional_callbacks selector_action: 2
end
