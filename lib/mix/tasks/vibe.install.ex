defmodule Mix.Tasks.Vibe.Install do
  @shortdoc "Build and install the local vibe executable"

  @moduledoc """
  Builds and installs the local `vibe` escript.

  This is a convenience wrapper around:

      mix escript.build
      mix escript.install --force

  After installation, make sure the printed Mix escripts directory is on your shell path.

  Common Elixir installs use:

      export PATH="$HOME/.mix/escripts:$PATH"

  ## Usage

      mix vibe.install
      mix vibe.install --no-force
  """

  use Mix.Task

  alias Mix.Task

  @impl true
  def run(argv) do
    force? = "--no-force" not in argv
    install_args = if force?, do: ["--force"], else: []

    Task.run("escript.build")
    Task.reenable("escript.install")
    Task.run("escript.install", install_args)

    print_path_hint()
  end

  defp print_path_hint do
    escripts_dir = Path.join(Mix.Utils.mix_home(), "escripts")

    if path_contains?(escripts_dir) do
      Mix.shell().info("vibe installed and available on PATH.")
    else
      Mix.shell().info("vibe installed to #{escripts_dir}.")
      Mix.shell().info(~s(Add it to PATH with: export PATH="#{escripts_dir}:$PATH"))
    end
  end

  defp path_contains?(dir) do
    System.get_env("PATH", "")
    |> String.split(path_separator(), trim: true)
    |> Enum.any?(&(Path.expand(&1) == dir))
  end

  defp path_separator do
    case :os.type() do
      {:win32, _} -> ";"
      _ -> ":"
    end
  end
end
