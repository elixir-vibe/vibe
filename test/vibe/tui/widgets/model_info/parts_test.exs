defmodule Vibe.TUI.Widgets.ModelInfo.PartsTest do
  use ExUnit.Case, async: true

  alias Vibe.Terminal.Width
  alias Vibe.TUI.Widgets.ModelInfo.Parts

  @theme Vibe.Terminal.Theme.default()

  test "model segment includes model and provider" do
    text = Parts.model(%{model: "provider:model", provider: "provider"}, @theme) |> visible()
    assert text =~ "provider:model"
    assert text =~ "via provider"
  end

  test "status segment formats effort usage cost and context" do
    text =
      Parts.status(
        %{
          effort: "high",
          subscription: "pro",
          usage: %{total_tokens: 1_500, total_cost: 0.1234},
          context_percent: 85
        },
        @theme
      )
      |> visible()

    assert text =~ "high"
    assert text =~ "pro"
    assert text =~ "1.5K"
    assert text =~ "$0.123"
    assert text =~ "ctx! 85%"
  end

  test "status segment omits zero tokens and uses reasoning fallback" do
    text = Parts.status(%{reasoning: "medium", usage: %{total_tokens: 0}}, @theme) |> visible()
    assert text =~ "medium"
    refute text =~ " 0"
  end

  defp visible(iodata), do: iodata |> IO.iodata_to_binary() |> Width.visible_text()
end
