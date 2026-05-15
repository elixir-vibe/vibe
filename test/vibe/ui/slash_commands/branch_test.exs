defmodule Vibe.UI.SlashCommands.BranchTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.SlashCommands.Branch

  test "spec has name branch" do
    assert Branch.spec().name == "branch"
  end

  test "empty args branches from last message" do
    state = %{messages: [%{}, %{}, %{}]}
    assert {:command, {:branch_session, %{seq: 2}}} = Branch.run("", state)
  end

  test "numeric arg sets specific seq" do
    assert {:command, {:branch_session, %{seq: 5}}} = Branch.run("5", %{messages: []})
  end

  test "errors on empty session" do
    assert {:events, [%{data: %{level: :error}}]} = Branch.run("", %{messages: [%{}]})
  end

  test "errors on invalid input" do
    assert {:events, [%{data: %{level: :error}}]} = Branch.run("abc", %{messages: []})
  end
end
