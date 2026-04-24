defmodule Exy.LLM.Model do
  @moduledoc """
  Model selection helpers.
  """

  @default "openai_codex:gpt-5.5"

  @spec default() :: String.t()
  def default, do: @default

  @spec resolve(keyword()) :: String.t()
  def resolve(opts \\ []) do
    Keyword.get(opts, :model) || System.get_env("EXY_MODEL") || default()
  end
end
