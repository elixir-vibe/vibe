defmodule Vibe.Model.Selection.Source do
  @moduledoc false

  @spec resolve(keyword(), (-> String.t())) :: String.t()
  def resolve(opts, default_fun) when is_list(opts) and is_function(default_fun, 0) do
    explicit_model(opts) || role_model(opts) || env_model() || default_fun.()
  end

  defp explicit_model(opts), do: Keyword.get(opts, :model)

  defp role_model(opts) do
    case Keyword.get(opts, :role) do
      nil -> nil
      role -> Vibe.Agent.Profile.model_for(role: role)
    end
  end

  defp env_model, do: System.get_env("VIBE_MODEL")
end
