defmodule Vibe.Agent.ProfileTest do
  use ExUnit.Case, async: false

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "vibe-agent-profiles-#{System.unique_integer([:positive])}.toml"
      )

    previous = Application.get_env(:vibe, :agent_profiles_file)
    Application.put_env(:vibe, :agent_profiles_file, path)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :agent_profiles_file, previous),
        else: Application.delete_env(:vibe, :agent_profiles_file)

      File.rm(path)
    end)

    {:ok, path: path}
  end

  test "generates and reads editable TOML role profiles", %{path: path} do
    refute File.exists?(path)
    assert {:ok, data} = Vibe.Agent.Profile.load()
    assert File.exists?(path)
    assert data["default_model"] == "openai_codex:gpt-5.5"
    assert data["default_effort"] == "medium"
    assert {:ok, %{"model" => model}} = Vibe.Agent.Profile.role(:coder)
    assert model == "openai_codex:gpt-5.5"
  end

  test "resolves model, system, tools, and provider options", %{path: path} do
    File.write!(path, """
    default_model = "default:model"
    default_effort = "low"

    [providers.openrouter]
    app_title = "Vibe Test"
    openai_reuse_websocket = true
    openai_stream_transport = "websocket"
    unknown_option = "ignored"

    [roles.scout]
    model = "openrouter:test/model"
    system = "Scout only"
    tools = ["read", "eval"]
    effort = "high"
    """)

    assert Vibe.Agent.Profile.default_model() == "default:model"
    assert Vibe.Agent.Profile.default_effort() == :low
    assert Vibe.Agent.Profile.model_for(role: :scout) == "openrouter:test/model"
    assert Vibe.Agent.Profile.effort_for(role: :scout) == :high
    assert Vibe.Agent.Profile.effort_for(role: :missing) == :low
    assert Vibe.Agent.Profile.system_for(role: :scout) == "Scout only"
    assert Vibe.Agent.Profile.tools_for(role: :scout) == ["read", "eval"]

    assert Vibe.Agent.Profile.provider_options(:openrouter) == [
             app_title: "Vibe Test",
             openai_reuse_websocket: true,
             openai_stream_transport: :websocket
           ]

    assert Vibe.Agent.Profile.models() == ["default:model", "openrouter:test/model"]
  end
end
