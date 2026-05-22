defmodule Vibe.Auth.WebToken.FileStore do
  @moduledoc false

  @spec read_or_create!(String.t(), (-> String.t())) :: String.t()
  def read_or_create!(path, token_fun) when is_binary(path) and is_function(token_fun, 0) do
    File.mkdir_p!(Path.dirname(path))
    if missing?(path), do: write_token_file!(path, token_fun.())
    path |> File.read!() |> String.trim()
  end

  defp missing?(path), do: not File.exists?(path)

  defp write_token_file!(path, token) do
    File.write!(path, token)
    File.chmod!(path, 0o600)
  end
end
