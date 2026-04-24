defmodule Mix.Tasks.Exy do
  @shortdoc "Launch Exy, the minimal BEAM-native coding agent"

  @moduledoc """
  Launches Exy from Mix.

      mix exy
      mix exy -p "Inspect runtime info"
      mix exy --login codex
      mix exy --eval "Exy.OTP.runtime_info()"

  Run `mix exy --help` for options.
  """

  use Mix.Task

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")
    Exy.CLI.main(argv)
  end
end
