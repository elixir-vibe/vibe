defmodule Vibe.Gateway.Options do
  @moduledoc "Shared gateway option parsing helpers."

  @spec optional_string(keyword(), atom()) :: String.t() | nil
  def optional_string(opts, key) do
    case Keyword.get(opts, key) do
      nil -> nil
      "" -> nil
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value -> to_string(value)
    end
  end
end
