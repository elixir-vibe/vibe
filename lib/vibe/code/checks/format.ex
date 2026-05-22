defmodule Vibe.Code.Checks.Format do
  @moduledoc false

  @spec stale_files([String.t()]) :: [String.t()]
  def stale_files(paths) when is_list(paths) do
    paths
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reject(&formatted?/1)
  end

  @spec formatted?(String.t()) :: boolean()
  def formatted?(path) do
    source = File.read!(path)
    {formatter, _opts} = Mix.Tasks.Format.formatter_for_file(path)
    formatted = source |> formatter.() |> IO.iodata_to_binary()
    source == formatted
  end
end
