defmodule Exy.UI.SlashCommands.ModelTest do
  use ExUnit.Case, async: true

  alias Exy.UI.SlashCommands.Model
  alias Exy.UI.State

  test "opens selector through semantic command" do
    assert Model.run("", State.new(session_id: "s1")) == {:command, :open_model_selector}
  end

  test "selects model through semantic command" do
    assert Model.run("openrouter:test/model", State.new(session_id: "s1")) ==
             {:command, {:select_model, %{model: "openrouter:test/model"}}}
  end
end
