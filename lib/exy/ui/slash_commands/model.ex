defmodule Exy.UI.SlashCommands.Model do
  @moduledoc "Internal implementation module."
  @behaviour Exy.UI.SlashCommands.Command

  @impl true
  def spec, do: %{name: "model", description: "Choose model", selectors: []}

  @impl true
  def run(args, _ui_state) when is_binary(args) do
    case String.trim(args) do
      "" -> {:command, :open_model_selector}
      model -> {:command, {:select_model, %{model: model}}}
    end
  end
end
