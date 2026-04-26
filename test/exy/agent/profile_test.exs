defmodule Exy.Agent.ProfileTest do
  use ExUnit.Case, async: false

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "exy-agent-profiles-#{System.unique_integer([:positive])}.toml"
      )

    previous = Application.get_env(:exy, :agent_profiles_file)
    Application.put_env(:exy, :agent_profiles_file, path)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :agent_profiles_file, previous),
        else: Application.delete_env(:exy, :agent_profiles_file)

      File.rm(path)
    end)

    {:ok, path: path}
  end

  test "generates and reads editable TOML role profiles", %{path: path} do
    refute File.exists?(path)
    assert {:ok, data} = Exy.Agent.Profile.load()
    assert File.exists?(path)
    assert data["default_model"] == "openai_codex:gpt-5.5"
    assert {:ok, %{"model" => model}} = Exy.Agent.Profile.role(:coder)
    assert model == "openai_codex:gpt-5.5"
  end

  test "resolves model, system, tools, and provider options", %{path: path} do
    File.write!(path, """
    default_model = "default:model"

    [providers.openrouter]
    app_title = "Exy Test"

    [roles.scout]
    model = "openrouter:test/model"
    system = "Scout only"
    tools = ["read", "eval"]
    """)

    assert Exy.Agent.Profile.default_model() == "default:model"
    assert Exy.Agent.Profile.model_for(role: :scout) == "openrouter:test/model"
    assert Exy.Agent.Profile.system_for(role: :scout) == "Scout only"
    assert Exy.Agent.Profile.tools_for(role: :scout) == ["read", "eval"]
    assert Exy.Agent.Profile.provider_options(:openrouter) == [app_title: "Exy Test"]
  end
end
