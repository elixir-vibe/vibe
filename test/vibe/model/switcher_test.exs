defmodule Vibe.Model.SwitcherTest do
  use ExUnit.Case, async: false

  alias Vibe.Model.Switcher

  setup do
    path =
      Path.join(System.tmp_dir!(), "vibe-switcher-#{System.unique_integer([:positive])}.toml")

    previous = Application.get_env(:vibe, :agent_profiles_file)
    Application.put_env(:vibe, :agent_profiles_file, path)

    File.write!(path, """
    default_model = "default:model"

    [roles.coder]
    model = "role:model"
    """)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :agent_profiles_file, previous),
        else: Application.delete_env(:vibe, :agent_profiles_file)

      File.rm(path)
    end)

    :ok
  end

  test "cycles model through configured options" do
    assert Switcher.model_options("current:model") == [
             "default:model",
             "role:model",
             "current:model"
           ]

    assert Switcher.cycle_model("default:model", :forward) == {:ok, "role:model"}
    assert Switcher.cycle_model("default:model", :backward) == {:ok, "role:model"}
  end

  test "cycles effort as atom values" do
    assert Switcher.cycle_effort(:medium) == :high
    assert Switcher.cycle_effort(:high) == :xhigh
    assert Switcher.cycle_effort(:xhigh) == :off
    assert Switcher.cycle_effort(nil) == :high
  end
end
