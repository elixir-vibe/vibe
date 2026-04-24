defmodule Exy.Prompts do
  @moduledoc false

  @spec path(String.t()) :: String.t()
  def path(name), do: Application.app_dir(:exy, Path.join("priv/prompts", name))

  @spec read!(String.t()) :: String.t()
  def read!(name), do: name |> path() |> File.read!()
end
