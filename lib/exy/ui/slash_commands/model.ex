defmodule Exy.UI.SlashCommands.Model do
  @moduledoc false

  @behaviour Exy.UI.SlashCommand

  alias Exy.UI.Event

  @impl true
  def spec, do: %{name: "model", description: "Choose model"}

  @impl true
  def run(_args, ui_state) do
    selector = %{
      kind: :model_selector,
      title: "Model",
      items: [ui_state.model],
      selected: 0,
      limit: 8
    }

    {:events, [Event.new(:selector_opened, ui_state.session_id, selector)]}
  end

  @impl true
  def selector_action(model, ui_state) when is_binary(model),
    do: {:events, [Event.new(:model_selected, ui_state.session_id, %{model: model})]}

  def selector_action(_item, _ui_state), do: :ignore
end
