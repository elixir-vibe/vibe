defmodule Vibe.Agent.Profile do
  @moduledoc """
  User-editable agent role/model profiles backed by TOML.
  """

  alias Vibe.Model.Effort

  @spec path() :: String.t()
  def path, do: Vibe.Paths.agent_profiles()

  @spec ensure!() :: :ok
  def ensure! do
    path = path()
    if missing?(path), do: copy_default_profile!(path)
    :ok
  end

  defp missing?(path), do: not File.exists?(path)

  defp copy_default_profile!(path) do
    source = default_profile_path()
    File.mkdir_p!(Path.dirname(path))
    File.cp!(source, path)
  end

  defp default_profile_path do
    Application.app_dir(:vibe, "priv/config/agent-profiles.toml")
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
      {:ok, data} -> Map.get(data, "default_model") || Vibe.Model.Default.model()
      {:error, _reason} -> Vibe.Model.Default.model()
    end
  end

  @spec default_effort() :: Effort.t()
  def default_effort do
    with {:ok, data} <- load(),
         value when is_binary(value) <- Map.get(data, "default_effort"),
         {:ok, effort} <- Effort.from_string(value) do
      effort
    else
      _ -> Effort.default()
    end
  end

  @spec model_for(keyword()) :: String.t() | nil
  def model_for(opts) do
    cond do
      model = Keyword.get(opts, :model) ->
        model

      role = Keyword.get(opts, :role) ->
        case role(role) do
          {:ok, data} -> Map.get(data, "model")
          {:error, _reason} -> nil
        end

      true ->
        default_model()
    end
  end

  @spec effort_for(keyword()) :: Effort.t()
  def effort_for(opts) do
    cond do
      effort = Keyword.get(opts, :effort) ->
        if Effort.valid?(effort), do: effort, else: default_effort()

      role = Keyword.get(opts, :role) ->
        role_effort(role) || default_effort()

      true ->
        default_effort()
    end
  end

  @spec models() :: [String.t()]
  def models do
    case load() do
      {:ok, data} ->
        roles = Map.get(data, "roles", %{})

        [
          Map.get(data, "default_model")
          | Enum.map(roles, fn {_role, profile} -> profile["model"] end)
        ]
        |> Enum.filter(&is_binary/1)
        |> Enum.uniq()

      {:error, _reason} ->
        [Vibe.Model.Default.model()]
    end
  end

  @spec system_for(keyword()) :: String.t() | nil
  def system_for(opts) do
    cond do
      system = Keyword.get(opts, :system) ->
        system

      role = Keyword.get(opts, :role) ->
        case role(role) do
          {:ok, data} -> Map.get(data, "system")
          {:error, _reason} -> nil
        end

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

  defp role_effort(role) do
    with {:ok, data} <- role(role),
         value when is_binary(value) <- Map.get(data, "effort"),
         {:ok, effort} <- Effort.from_string(value) do
      effort
    else
      _ -> nil
    end
  end

  @spec provider_options(atom() | String.t()) :: keyword()
  def provider_options(provider) do
    with {:ok, data} <- load(),
         providers when is_map(providers) <- Map.get(data, "providers", %{}),
         opts when is_map(opts) <- Map.get(providers, to_string(provider)) do
      opts
      |> Enum.flat_map(&provider_option/1)
    else
      _ -> []
    end
  end

  defp provider_option({"app_title", value}), do: [app_title: value]

  defp provider_option({"openai_reuse_websocket", value}) when is_boolean(value),
    do: [openai_reuse_websocket: value]

  defp provider_option({"openai_stream_transport", "sse"}), do: [openai_stream_transport: :sse]

  defp provider_option({"openai_stream_transport", "websocket"}),
    do: [openai_stream_transport: :websocket]

  defp provider_option({"reasoning_effort", value}), do: [reasoning_effort: value]
  defp provider_option({"session_id", value}), do: [session_id: value]
  defp provider_option({:app_title, value}), do: [app_title: value]

  defp provider_option({:openai_reuse_websocket, value}) when is_boolean(value),
    do: [openai_reuse_websocket: value]

  defp provider_option({:openai_stream_transport, value}) when value in [:sse, :websocket],
    do: [openai_stream_transport: value]

  defp provider_option({:reasoning_effort, value}), do: [reasoning_effort: value]
  defp provider_option({:session_id, value}), do: [session_id: value]
  defp provider_option({_unknown, _value}), do: []

  @spec disabled_plugins() :: [module()]
  def disabled_plugins do
    case load() do
      {:ok, data} ->
        data
        |> Map.get("disabled_plugins", [])
        |> Enum.flat_map(&resolve_plugin_module/1)

      {:error, _reason} ->
        []
    end
  end

  defp resolve_plugin_module(name) when is_binary(name) do
    module =
      if String.starts_with?(name, "Elixir.") or String.starts_with?(name, "Vibe.") do
        Module.concat([name])
      else
        Module.concat(["Vibe", "Plugins", Macro.camelize(name)])
      end

    if Code.ensure_loaded?(module), do: [module], else: []
  end

  defp resolve_plugin_module(_name), do: []
end
