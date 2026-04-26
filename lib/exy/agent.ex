defmodule Exy.Agent do
  @moduledoc """
  Convenience helpers for starting Exy's Jido-backed coding agent.
  """

  alias Exy.Session.Store

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    with {:ok, opts} <- resolve_opts(opts),
         :ok <- ensure_provider_credentials(opts) do
      configure_model_alias(opts)

      with {:ok, pid} <- Exy.Jido.start_agent(Exy.Agent.Coding) do
        Jido.AI.set_system_prompt(pid, system_prompt(opts))
        session_id = Keyword.get(opts, :session_id) || Exy.Session.Store.new_id()
        Exy.Session.Processes.register(pid, session_id)
        {:ok, pid}
      end
    end
  end

  @spec ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) do
    with {:ok, opts} <- resolve_opts(opts),
         {:ok, pid} <- start_link(opts) do
      try do
        ask_sync(pid, prompt, opts)
      after
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end
  end

  @spec ask_sync(pid() | atom(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask_sync(pid, prompt, opts \\ []) do
    session_id =
      Keyword.get(opts, :session_id) || Exy.Session.Processes.session_id(pid) ||
        Exy.Session.Store.new_id()

    Store.append_trajectory(:user_message, %{prompt: prompt}, session_id: session_id)

    result =
      try do
        Exy.Agent.Streaming.register(pid, opts)
        Exy.Agent.Coding.ask_sync(pid, prompt, opts)
      after
        Exy.Agent.Streaming.unregister(pid)
      end

    result = enrich_result_usage(result, pid)

    data =
      case result do
        {:ok, response} -> %{result: response}
        {:error, reason} -> %{error: inspect(reason)}
      end

    Store.append_trajectory(:assistant_message, data, session_id: session_id)

    if usage = Exy.Model.Usage.from_response(result) do
      Store.append_trajectory(:llm_usage, usage, session_id: session_id)
    end

    result
  end

  defp enrich_result_usage({:ok, response}, pid) do
    case agent_usage(pid) do
      usage when is_map(usage) and map_size(usage) > 0 -> {:ok, %{output: response, usage: usage}}
      _usage -> {:ok, response}
    end
  end

  defp enrich_result_usage(result, _pid), do: result

  defp agent_usage(pid) do
    with true <- Process.alive?(pid), {:ok, status} <- safe_status(pid) do
      get_in(status.raw_state, [:__strategy__, :usage]) || status.snapshot.details[:usage]
    else
      _other -> nil
    end
  end

  defp safe_status(pid) do
    Jido.AgentServer.status(pid)
  catch
    :exit, _reason -> {:error, :agent_unavailable}
  end

  defp system_prompt(opts) do
    base =
      case Exy.Memory.Manager.system_prompt_block() do
        "" -> Exy.Prompts.system()
        memory -> Exy.Prompts.system() <> "\n\n" <> memory
      end

    case Keyword.get(opts, :system) do
      system when is_binary(system) and system != "" ->
        base <> "\n\nRole instructions:\n" <> system

      _system ->
        base
    end
  end

  defp resolve_opts(opts) do
    with :ok <- validate_role(opts) do
      opts =
        opts
        |> put_role_model()
        |> put_role_system()
        |> put_role_tools()
        |> put_provider_options()

      {:ok, opts}
    end
  end

  defp validate_role(opts) do
    role = Keyword.get(opts, :role)

    cond do
      is_nil(role) ->
        :ok

      Keyword.has_key?(opts, :model) or Keyword.has_key?(opts, :system) ->
        :ok

      match?({:ok, _profile}, Exy.Agent.Profile.role(role)) ->
        :ok

      true ->
        {:error, {:unknown_role, role}}
    end
  end

  defp put_role_model(opts) do
    Keyword.put_new_lazy(opts, :model, fn -> Exy.Agent.Profile.model_for(opts) end)
  end

  defp put_role_system(opts) do
    if Keyword.has_key?(opts, :system) do
      opts
    else
      case Exy.Agent.Profile.system_for(opts) do
        nil -> opts
        system -> Keyword.put(opts, :system, system)
      end
    end
  end

  defp put_role_tools(opts) do
    if Keyword.has_key?(opts, :allowed_tools) do
      opts
    else
      case Exy.Agent.Profile.tools_for(opts) do
        tools when is_list(tools) -> Keyword.put(opts, :allowed_tools, tools)
        _tools -> opts
      end
    end
  end

  defp put_provider_options(opts) do
    model = Keyword.get(opts, :model) || Exy.Model.Config.default()
    provider = model |> to_string() |> String.split(":", parts: 2) |> hd()
    provider_options = Exy.Agent.Profile.provider_options(provider)

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

  defp configure_model_alias(opts) do
    current = Application.get_env(:jido_ai, :model_aliases, %{})

    Application.put_env(
      :jido_ai,
      :model_aliases,
      Map.put(current, :exy, Exy.Model.Config.resolve(opts))
    )
  end

  defp ensure_provider_credentials(opts) do
    opts
    |> Exy.Model.Config.resolve()
    |> to_string()
    |> String.split(":", parts: 2)
    |> hd()
    |> auth_provider_name()
    |> Exy.Auth.ensure_fresh()
    |> case do
      {:ok, _credentials} -> :ok
      {:error, {:unknown_auth_provider, _provider}} -> :ok
      {:error, :not_found} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp auth_provider_name("openai_codex"), do: "openai-codex"
  defp auth_provider_name(provider), do: provider
end
