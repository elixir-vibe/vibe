defmodule Vibe.Build do
  @moduledoc "Compile-time build metadata embedding."
  @spec id() :: String.t()
  def id do
    modules = [Vibe, Vibe.Session, Vibe.TUI, Vibe.CLI]

    modules
    |> Enum.map(&beam_fingerprint/1)
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec version() :: String.t()
  def version, do: :vibe |> Application.spec(:vsn) |> to_string()

  defp beam_fingerprint(module) do
    case :code.which(module) do
      path when is_list(path) ->
        path = List.to_string(path)

        case File.stat(path, time: :posix) do
          {:ok, stat} -> {module, stat.size, stat.mtime}
          {:error, _reason} -> {module, module.module_info(:md5)}
        end

      other ->
        {module, other}
    end
  end
end
