defmodule Vibe.Model.Config do
  @moduledoc """
  Model selection helpers.
  """

  @default "openai_codex:gpt-5.5"

  @spec default() :: String.t()
  def default, do: @default

  @spec resolve(keyword()) :: String.t()
  def resolve(opts \\ []) do
    Keyword.get(opts, :model) || role_model(opts) || System.get_env("VIBE_MODEL") || default()
  end

  defp role_model(opts) do
    case Keyword.get(opts, :role) do
      nil -> nil
      role -> Vibe.Agent.Profile.model_for(role: role)
    end
  end
end
