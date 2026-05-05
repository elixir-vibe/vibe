defmodule Exy.Prompt.ClipboardImage do
  @moduledoc "Saves a PNG image from the system clipboard for prompt attachment."

  alias Exy.Command

  @type save_result :: {:ok, Path.t()} | {:error, term()}

  @spec save(keyword()) :: save_result()
  def save(opts \\ []) do
    session_id = Keyword.get(opts, :session_id, "clipboard")

    root =
      Keyword.get_lazy(opts, :root, fn -> Exy.Files.Artifacts.session_artifact_dir(session_id) end)

    path = Path.join([root, "clipboard", filename()])

    with :ok <- ensure_pngpaste(),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- run_pngpaste(path) do
      {:ok, path}
    end
  end

  defp ensure_pngpaste do
    case System.find_executable("pngpaste") do
      nil -> {:error, :pngpaste_not_found}
      _path -> :ok
    end
  end

  defp run_pngpaste(path) do
    case Command.run(["pngpaste", path], timeout: 5_000) do
      %{exit_status: 0} ->
        :ok

      %{stderr: stderr, stdout: stdout} ->
        {:error, {:clipboard_image_unavailable, output(stderr, stdout)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp output(stderr, stdout) do
    [stderr, stdout]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp filename do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = System.unique_integer([:positive])
    "clipboard-#{timestamp}-#{suffix}.png"
  end
end
