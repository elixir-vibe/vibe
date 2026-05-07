defmodule Vibe.SkillScriptTest do
  use ExUnit.Case, async: false

  alias Vibe.Plugin.API

  setup do
    dir = Path.join(System.tmp_dir!(), "vibe-skill-script-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    previous_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, dir)

    on_exit(fn ->
      if previous_home,
        do: Application.put_env(:vibe, :home_dir, previous_home),
        else: Application.delete_env(:vibe, :home_dir)

      File.rm_rf(dir)
    end)

    {:ok, dir: dir}
  end

  test "loads executable skill with DSL metadata, docs, and API", %{dir: dir} do
    skills_dir = Path.join(dir, "skills")
    File.mkdir_p!(skills_dir)
    path = Path.join(skills_dir, "demo.skill.exs")

    File.write!(path, skill_source("DemoSkill", "demo-skill", "Demo"))

    assert {:ok, [skill]} = Vibe.Skill.Loader.load_file(path)
    assert skill.name == "demo-skill"
    assert skill.module == VibeSkill.DemoSkill
    assert skill.metadata.description == "Executable demo skill"
    assert skill.markdown =~ "# Demo Skill"
    assert [%API{alias: :Demo, module: VibeSkill.DemoSkill}] = skill.apis
    assert function_exported?(VibeSkill.DemoSkill, :slug, 1)
  end

  test "discovered executable skill APIs are available in one-off eval", %{dir: dir} do
    skills_dir = Path.join(dir, "skills")
    File.mkdir_p!(skills_dir)

    File.write!(
      Path.join(skills_dir, "eval.skill.exs"),
      skill_source("EvalSkill", "eval-skill", "EvalSkill")
    )

    assert {:ok, result} = Vibe.Eval.once(~S|EvalSkill.slug("Hello Eval")|)
    assert result.output =~ "hello-eval"
  end

  test "formats matching skills as markdown context", %{dir: dir} do
    skills_dir = Path.join([dir, "skills", "weather-skill"])
    File.mkdir_p!(skills_dir)

    File.write!(Path.join(skills_dir, "SKILL.md"), """
    ---
    name: weather-skill
    description: Use weather.gov for weather answers
    triggers:
      - weather source
    ---
    # Weather Skill

    Always prefer weather.gov as the weather source.
    """)

    context = Vibe.Skill.context("check weather source", limit: 1)

    assert context =~ "## Active skills"
    assert context =~ "### weather-skill"
    assert context =~ "Always prefer weather.gov"
    refute context =~ "<skills>"
  end

  test "creates an executable skill draft from a session", %{dir: dir} do
    session_id = "skill-source-session"
    Vibe.Session.Store.ensure_session(session_id, ~U[2026-01-01 00:00:00Z], cwd: dir)

    :ok =
      Vibe.UI.Event.new(:user_message_added, session_id, %{text: "Debug reusable workflow"},
        at: ~U[2026-01-01 00:00:01Z]
      )
      |> Vibe.Session.Store.append_ui_event(1)

    assert {:ok, path} = Vibe.Skill.create_from_session(session_id, "debug-workflow")
    assert String.ends_with?(path, "debug-workflow/skill.exs")
    assert File.read!(path) =~ "Generated from Vibe session `#{session_id}`"
    assert {:ok, [skill]} = Vibe.Skill.Loader.load_file(path)
    assert skill.name == "debug-workflow"
  end

  defp skill_source(module_suffix, name, alias_name) do
    quote = ~s(\"\"\")

    """
    defmodule VibeSkill.#{module_suffix} do
      use Vibe.Skill.Script

      skill do
        name #{inspect(name)}
        version "0.1.0"
        description "Executable demo skill"
        triggers ["demo"]
        alias_as #{alias_name}
        examples ["#{alias_name}.slug(\\\"Hello Skill\\\")"]
      end

      @moduledoc #{quote}
      # Demo Skill

      A skill with executable helpers.
      #{quote}

      def slug(text) do
        text
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")
      end
    end
    """
  end
end
