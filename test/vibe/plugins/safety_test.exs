defmodule Vibe.Plugins.SafetyTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugins.Safety.Patterns, as: Safety

  test "detects GitHub PR creation" do
    assert {:ok, "Create GitHub PR"} = Safety.check_command("gh pr create --title fix")
    assert {:ok, "Merge GitHub PR"} = Safety.check_command("gh pr merge 123")
  end

  test "detects GitLab MR creation" do
    assert {:ok, "Create GitLab MR"} = Safety.check_command("glab mr create")
    assert {:ok, "Merge GitLab MR"} = Safety.check_command("glab mr merge 456")
  end

  test "detects force push" do
    assert {:ok, "Force push"} = Safety.check_command("git push --force origin main")
    assert {:ok, "Force push"} = Safety.check_command("git push -f origin main")
  end

  test "detects dangerous rm" do
    assert {:ok, "Delete from root"} = Safety.check_command("rm -rf /etc")
  end

  test "detects sudo" do
    assert {:ok, "Run as root"} = Safety.check_command("sudo apt install something")
  end

  test "detects database drops" do
    assert {:ok, "Drop database"} = Safety.check_command("dropdb myapp_prod")
    assert {:ok, "Drop database object"} = Safety.check_command("DROP TABLE users;")
  end

  test "safe commands pass through" do
    assert :safe = Safety.check_command("mix test")
    assert :safe = Safety.check_command("git status")
    assert :safe = Safety.check_command("gh pr list")
    assert :safe = Safety.check_command("rm -rf _build")
    assert :safe = Safety.check_command("git push origin main")
  end

  test "plugin blocks dangerous commands and waits for confirmation" do
    session_id = "safety-confirm-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    task =
      Task.async(fn ->
        Vibe.Plugins.Safety.before_command(
          "gh pr create --title fix",
          %{session_id: session_id},
          %{}
        )
      end)

    Process.sleep(50)

    Vibe.Plugins.Safety.handle_event(
      %{type: :selector_confirmed, data: %{selector: :safety_confirmation, item: "Yes, proceed"}},
      %{session_id: session_id},
      %{}
    )

    assert {:ok, _state} = Task.await(task)
    GenServer.stop(session)
  end

  test "plugin blocks and cancels on rejection" do
    session_id = "safety-cancel-#{System.unique_integer([:positive])}"
    {:ok, session} = Vibe.Session.start_link(session_id: session_id, persist?: false)

    task =
      Task.async(fn ->
        Vibe.Plugins.Safety.before_command(
          "gh pr create --title fix",
          %{session_id: session_id},
          %{}
        )
      end)

    Process.sleep(50)

    Vibe.Plugins.Safety.handle_event(
      %{type: :selector_closed},
      %{session_id: session_id},
      %{}
    )

    assert {:block, _reason, _state} = Task.await(task)
    GenServer.stop(session)
  end

  test "safe commands pass through without blocking" do
    assert {:ok, _state} =
             Vibe.Plugins.Safety.before_command("mix test", %{session_id: "x"}, %{})
  end
end
