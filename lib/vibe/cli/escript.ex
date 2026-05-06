defmodule Vibe.CLI.Escript do
  @moduledoc "Escript entrypoint for the standalone `vibe` binary."
  @version Mix.Project.config()[:version]
  def main(argv) do
    %{opts: opts} = Vibe.CLI.parse(argv)

    cond do
      opts[:help] -> print_help()
      opts[:version] -> Vibe.CLI.main(argv)
      true -> run(argv, opts)
    end
  end

  defp run(argv, _opts) do
    with :ok <- prepare_priv_dirs(),
         {:ok, _apps} <- Application.ensure_all_started(:vibe) do
      Vibe.CLI.main(argv)
    end
  end

  defp print_help do
    {:docs_v1, _anno, _beam_language, _format, %{"en" => moduledoc}, _metadata, _docs} =
      Code.fetch_docs(Mix.Tasks.Vibe)

    IO.puts(moduledoc)
  end

  defp prepare_priv_dirs do
    case escript_path() do
      {:ok, path} -> extract_priv_dirs(path)
      :error -> :ok
    end
  end

  defp escript_path do
    path = :escript.script_name() |> to_string()

    if File.regular?(path) do
      {:ok, path}
    else
      :error
    end
  rescue
    _ -> :error
  end

  defp extract_priv_dirs(path) do
    with {:ok, sections} <- :escript.extract(to_charlist(path), []),
         {:archive, archive} <- List.keyfind(sections, :archive, 0) do
      root = cache_root(path)
      marker = Path.join(root, ".complete")

      unless File.exists?(marker) do
        File.rm_rf!(root)
        File.mkdir_p!(root)
        {:ok, _} = :zip.extract(archive, cwd: to_charlist(root))
        File.write!(marker, @version)
      end

      add_code_paths(root)
      configure_extracted_priv(root)
      :ok
    else
      _ -> :ok
    end
  end

  defp cache_root(path) do
    stat = File.stat!(path, time: :posix)
    fingerprint = :erlang.phash2({Path.expand(path), stat.size, stat.mtime})

    Path.join([
      to_string(:filename.basedir(:user_cache, "vibe")),
      "escripts",
      @version,
      Integer.to_string(fingerprint, 16)
    ])
  end

  defp add_code_paths(root) do
    root
    |> File.ls!()
    |> Enum.map(&Path.join([root, &1, "ebin"]))
    |> Enum.filter(&File.dir?/1)
    |> Enum.each(&:code.add_patha(to_charlist(&1)))
  end

  defp configure_extracted_priv(root) do
    Application.put_env(:tzdata, :data_dir, Path.join([root, "tzdata", "priv"]))

    Application.put_env(
      :llm_db,
      :snapshot_path,
      Path.join([root, "llm_db", "priv", "llm_db", "snapshot.json"])
    )

    Application.put_env(
      :llm_db,
      :history_dir,
      Path.join([root, "llm_db", "priv", "llm_db", "history"])
    )
  end
end
