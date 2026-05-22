defmodule Vibe.Session.Command.BackgroundTest do
  use ExUnit.Case, async: true

  alias Vibe.Session.Command.Background

  test "spec has name bg and alias background" do
    spec = Background.spec()
    assert spec.name == "bg"
    assert "background" in spec.aliases
  end

  test "run returns background_session command" do
    assert {:command, :background_session} = Background.run("", %{})
    assert {:command, :background_session} = Background.run("some args", %{})
  end
end
