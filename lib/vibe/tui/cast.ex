defmodule Vibe.TUI.Cast do
  @moduledoc """
  Vibe TUI recording entrypoint backed by TTYCast.
  """

  alias Vibe.TUI.Cast.Writer

  @doc "Starts a TTYCast writer unless recording is disabled."
  @spec start_writer(keyword()) :: {:ok, pid() | nil} | {:error, term()}
  def start_writer(opts) do
    case path_from_opts(opts) do
      nil -> {:ok, nil}
      path -> Writer.start_link(writer_opts(opts, path))
    end
  end

  @doc "Returns the path configured by CLI opts or environment variables."
  @spec path_from_opts(keyword()) :: String.t() | nil
  def path_from_opts(opts) do
    cond do
      path = Keyword.get(opts, :cast) -> path
      path = System.get_env("VIBE_TUI_CAST") -> path
      dir = System.get_env("VIBE_TUI_CAST_DIR") -> Path.join(dir, generated_name(opts))
      true -> nil
    end
  end

  defdelegate open(path_or_cast), to: TTYCast
  defdelegate open!(path_or_cast), to: TTYCast

  @doc "Exports a TTYCast recording to asciinema v2 JSONL."
  def export_asciinema(path_or_cast, output_path),
    do: TTYCast.export(path_or_cast, :asciinema, output_path)

  defp writer_opts(opts, path) do
    opts
    |> Keyword.put(:path, path)
    |> Keyword.put_new(:input_policy, input_policy(opts))
    |> Keyword.put_new(:metadata, metadata(opts))
  end

  defp input_policy(opts) do
    cond do
      Keyword.get(opts, :record_input) -> :raw
      System.get_env("VIBE_TUI_CAST_INPUT") == "1" -> :raw
      true -> :redacted
    end
  end

  defp metadata(opts) do
    %{
      app: :vibe,
      session_id: Keyword.get(opts, :session_id),
      cwd: Keyword.get_lazy(opts, :cwd, &File.cwd!/0),
      term: System.get_env("TERM")
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp generated_name(opts) do
    session_id = Keyword.get(opts, :session_id, "session")
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    "#{timestamp}-#{session_id}.ttycast"
  end
end
