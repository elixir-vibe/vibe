defmodule Exy.Agent.Profile do
  @moduledoc """
  User-editable agent role/model profiles backed by TOML.
  """

  @default_path Application.app_dir(:exy, "priv/config/agent-profiles.toml")
  @external_resource @default_path

  @spec path() :: String.t()
  def path, do: Exy.Paths.agent_profiles()

  @spec ensure!() :: :ok
  def ensure! do
    path = path()

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))
      File.cp!(@default_path, path)
    end

    :ok
  end

  @spec load() :: {:ok, map()} | {:error, term()}
  def load do
    ensure!()

    path()
    |> File.read()
    |> case do
      {:ok, text} -> Toml.decode(text)
      error -> error
    end
  end

  @spec role(atom() | String.t()) :: {:ok, map()} | {:error, term()}
  def role(role) do
    with {:ok, data} <- load(),
         %{} = roles <- Map.get(data, "roles", %{}),
         %{} = role_data <- Map.get(roles, to_string(role)) do
      {:ok, role_data}
    else
      nil -> {:error, {:unknown_role, role}}
      other -> other
    end
  end

  @spec default_model() :: String.t()
  def default_model do
    case load() do
      {:ok, data} -> Map.get(data, "default_model") || Exy.Model.Config.default()
      {:error, _reason} -> Exy.Model.Config.default()
    end
  end

  @spec model_for(keyword()) :: String.t() | nil
  def model_for(opts) do
    cond do
      model = Keyword.get(opts, :model) ->
        model

      role = Keyword.get(opts, :role) ->
        with {:ok, data} <- role(role), do: Map.get(data, "model")

      true ->
        default_model()
    end
  end

  @spec system_for(keyword()) :: String.t() | nil
  def system_for(opts) do
    cond do
      system = Keyword.get(opts, :system) ->
        system

      role = Keyword.get(opts, :role) ->
        with {:ok, data} <- role(role), do: Map.get(data, "system")

      true ->
        nil
    end
  end

  @spec tools_for(keyword()) :: [String.t()] | nil
  def tools_for(opts) do
    cond do
      tools = Keyword.get(opts, :tools) ->
        tools

      role = Keyword.get(opts, :role) ->
        with {:ok, data} <- role(role), tools when is_list(tools) <- Map.get(data, "tools") do
          tools
        else
          _ -> nil
        end

      true ->
        nil
    end
  end

  @spec provider_options(atom() | String.t()) :: keyword()
  def provider_options(provider) do
    with {:ok, data} <- load(),
         providers when is_map(providers) <- Map.get(data, "providers", %{}),
         opts when is_map(opts) <- Map.get(providers, to_string(provider)) do
      Enum.map(opts, fn {key, value} -> {String.to_atom(key), value} end)
    else
      _ -> []
    end
  end
end
