defmodule Vibe.Code.Checks.RunnerTest do
  use ExUnit.Case, async: true

  alias Vibe.Code.Checks.Runner
  alias Vibe.Code.Checks.Result

  test "runs checks inside configured working directory" do
    dir = Path.join(System.tmp_dir!(), "vibe-check-runner-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      expected = Path.basename(dir)

      assert {:ok, [%Result{name: :cwd, status: :ok, details: ^expected}]} =
               Runner.run_all([checks: [:cwd], cwd: dir], fn :cwd, _opts ->
                 %Result{name: :cwd, status: :ok, details: File.cwd!() |> Path.basename()}
               end)
    after
      File.rm_rf(dir)
    end
  end

  test "returns error when any check fails" do
    assert {:error, [%Result{name: :bad, status: :error}]} =
             Runner.run_all([checks: [:bad]], fn :bad, _opts ->
               %Result{name: :bad, status: :error, details: :nope}
             end)
  end
end
