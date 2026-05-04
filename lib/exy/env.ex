defmodule Exy.Env do
  @moduledoc "Runtime environment detection helpers."
  @spec to_charlist_pairs(map() | keyword()) :: [{charlist(), charlist()}]
  def to_charlist_pairs(env) when is_map(env), do: env |> Map.to_list() |> to_charlist_pairs()

  def to_charlist_pairs(env),
    do: Enum.map(env, fn {key, value} -> {to_charlist(key), to_charlist(value)} end)
end
