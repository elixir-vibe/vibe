defmodule Vibe.Session.EvalInputTest do
  use ExUnit.Case, async: true

  alias Vibe.Session.EvalInput

  test "parses bang eval input" do
    assert EvalInput.parse("!1 + 2") == {:eval, "1 + 2", true}

    assert EvalInput.parse("!!  Vibe.Telemetry.summary(limit: 10) ") ==
             {:eval, "Vibe.Telemetry.summary(limit: 10)", false}
  end

  test "keeps non-eval prompts as prompts" do
    assert EvalInput.parse("hello") == :prompt
    assert EvalInput.parse("!") == :prompt
    assert EvalInput.parse("!!") == :prompt
  end
end
