defmodule Vibe.Agent.Options do
  @moduledoc "Agent startup option resolution and validation."
  @spec resolve(keyword()) :: {:ok, keyword()} | {:error, term()}
  def resolve(opts) do
    with :ok <- validate_role(opts) do
      opts =
        opts
        |> put_role_model()
        |> put_role_system()
        |> put_role_tools()
        |> put_role_effort()
        |> put_provider_options()

      {:ok, opts}
    end
  end

  @spec system_prompt(keyword()) :: String.t()
  def system_prompt(opts) do
    context = %{model: Keyword.get(opts, :model)}

    parts =
      [
        Vibe.Prompts.system(),
        non_empty(Vibe.Memory.Manager.system_prompt_block()),
        plugin_system_prompt_blocks(context),
        case Keyword.get(opts, :system) do
          system when is_binary(system) and system != "" -> "Role instructions:\n" <> system
          _system -> nil
        end
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, "\n\n")
  end

  defp plugin_system_prompt_blocks(context) do
    if Process.whereis(Vibe.Plugin.Manager) do
      Vibe.Plugin.Manager.system_prompt_blocks(context)
    else
      []
    end
  rescue
    error ->
      require Logger
      Logger.warning("Plugin system_prompt_blocks failed: #{Exception.message(error)}")
      []
  end

  defp non_empty(""), do: nil
  defp non_empty(text), do: text

  @spec configure_model_alias(keyword()) :: :ok
  def configure_model_alias(opts) do
    current = Application.get_env(:jido_ai, :model_aliases, %{})

    Application.put_env(
      :jido_ai,
      :model_aliases,
      Map.put(current, :vibe, Vibe.Model.Config.resolve(opts))
    )
  end

  @spec ensure_provider_credentials(keyword()) :: :ok | {:error, term()}
  def ensure_provider_credentials(opts) do
    opts
    |> Vibe.Model.Config.resolve()
    |> to_string()
    |> String.split(":", parts: 2)
    |> hd()
    |> auth_provider_name()
    |> Vibe.Auth.ensure_fresh()
    |> case do
      {:ok, _credentials} -> :ok
      {:error, {:unknown_auth_provider, _provider}} -> :ok
      {:error, :not_found} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_role(opts) do
    role = Keyword.get(opts, :role)

    cond do
      is_nil(role) ->
        :ok

      Keyword.has_key?(opts, :model) or Keyword.has_key?(opts, :system) ->
        :ok

      match?({:ok, _profile}, Vibe.Agent.Profile.role(role)) ->
        :ok

      true ->
        {:error, {:unknown_role, role}}
    end
  end

  defp put_role_model(opts) do
    Keyword.put_new_lazy(opts, :model, fn -> Vibe.Agent.Profile.model_for(opts) end)
  end

  defp put_role_system(opts) do
    if Keyword.has_key?(opts, :system) do
      opts
    else
      case Vibe.Agent.Profile.system_for(opts) do
        nil -> opts
        system -> Keyword.put(opts, :system, system)
      end
    end
  end

  defp put_role_tools(opts) do
    if Keyword.has_key?(opts, :allowed_tools) do
      opts
    else
      case Vibe.Agent.Profile.tools_for(opts) do
        tools when is_list(tools) -> Keyword.put(opts, :allowed_tools, tools)
        _tools -> opts
      end
    end
  end

  defp put_role_effort(opts) do
    Keyword.put_new_lazy(opts, :effort, fn -> Vibe.Agent.Profile.effort_for(opts) end)
  end

  defp put_provider_options(opts) do
    model = Keyword.get(opts, :model) || Vibe.Model.Config.default()
    provider = model |> to_string() |> String.split(":", parts: 2) |> hd()

    provider_options =
      provider
      |> Vibe.Agent.Profile.provider_options()
      |> maybe_put_effort(Keyword.get(opts, :effort))

    if provider_options == [] do
      opts
    else
      Keyword.update(
        opts,
        :provider_options,
        provider_options,
        &Keyword.merge(provider_options, &1)
      )
    end
  end

  defp maybe_put_effort(provider_options, effort)
       when effort in [:minimal, :low, :medium, :high, :xhigh] do
    Keyword.put_new(provider_options, :reasoning_effort, Atom.to_string(effort))
  end

  defp maybe_put_effort(provider_options, _effort), do: provider_options

  defp auth_provider_name("openai_codex"), do: "openai-codex"
  defp auth_provider_name(provider), do: provider
end
