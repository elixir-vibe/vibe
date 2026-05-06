defmodule Vibe.Memory.Manager do
  @moduledoc "Curated long-term memory lifecycle: turn hooks, sync, and recall."
  use GenServer

  alias Vibe.Support.Lists

  defstruct providers: []

  @type provider_entry :: %{module: module(), state: term(), external?: boolean()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec load(module(), keyword()) :: :ok | {:error, term()}
  def load(module, opts \\ []), do: GenServer.call(__MODULE__, {:load, module, opts})

  @spec unload(module()) :: :ok
  def unload(module), do: GenServer.call(__MODULE__, {:unload, module})

  @spec providers() :: [module()]
  def providers, do: GenServer.call(__MODULE__, :providers)

  @spec system_prompt_block() :: String.t()
  def system_prompt_block, do: GenServer.call(__MODULE__, :system_prompt_block)

  @spec prefetch(String.t(), map()) :: String.t()
  def prefetch(query, context \\ %{}), do: GenServer.call(__MODULE__, {:prefetch, query, context})

  @spec sync_turn(String.t(), String.t(), map()) :: :ok
  def sync_turn(user, assistant, context \\ %{}),
    do: GenServer.cast(__MODULE__, {:sync_turn, user, assistant, context})

  @spec on_turn_start(non_neg_integer(), String.t(), map()) :: :ok
  def on_turn_start(turn, message, context \\ %{}),
    do: GenServer.cast(__MODULE__, {:on_turn_start, turn, message, context})

  @spec on_session_end([map()], map()) :: :ok
  def on_session_end(messages, context \\ %{}),
    do: GenServer.cast(__MODULE__, {:on_session_end, messages, context})

  @spec on_pre_compress([map()], map()) :: String.t()
  def on_pre_compress(messages, context \\ %{}),
    do: GenServer.call(__MODULE__, {:on_pre_compress, messages, context})

  @spec on_delegation(String.t(), String.t(), map()) :: :ok
  def on_delegation(task, result, context \\ %{}),
    do: GenServer.cast(__MODULE__, {:on_delegation, task, result, context})

  @impl true
  def init(opts) do
    modules = Keyword.get(opts, :providers, configured_providers())

    providers =
      modules
      |> Enum.reduce([], fn module, providers ->
        case start_provider(module, []) do
          {:ok, provider} -> [provider | providers]
          _ -> providers
        end
      end)
      |> Enum.reverse()

    {:ok, %__MODULE__{providers: providers}}
  end

  @impl true
  def handle_call({:load, module, opts}, _from, state) do
    external? = module != Vibe.Memory.BuiltinProvider
    external_loaded? = Enum.any?(state.providers, & &1.external?)

    cond do
      Enum.any?(state.providers, &(&1.module == module)) ->
        {:reply, {:error, :already_loaded}, state}

      external? and external_loaded? ->
        {:reply, {:error, :external_provider_already_loaded}, state}

      true ->
        case start_provider(module, opts) do
          {:ok, provider} ->
            {:reply, :ok, %{state | providers: append_provider(state.providers, provider)}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:unload, module}, _from, state) do
    {removed, providers} = Enum.split_with(state.providers, &(&1.module == module))
    Enum.each(removed, &apply_provider(&1, :shutdown, []))
    {:reply, :ok, %{state | providers: providers}}
  end

  def handle_call(:providers, _from, state),
    do: {:reply, Enum.map(state.providers, & &1.module), state}

  def handle_call(:system_prompt_block, _from, state) do
    {:reply, call_join(state.providers, :system_prompt_block, []), state}
  end

  def handle_call({:prefetch, query, context}, _from, state) do
    {:reply, call_join(state.providers, :prefetch, [query, context]), state}
  end

  def handle_call({:on_pre_compress, messages, context}, _from, state) do
    {:reply, call_join(state.providers, :on_pre_compress, [messages, context]), state}
  end

  @impl true
  def handle_cast({:sync_turn, user, assistant, context}, state) do
    each_provider(state.providers, :sync_turn, [user, assistant, context])
    {:noreply, state}
  end

  def handle_cast({:on_turn_start, turn, message, context}, state) do
    each_provider(state.providers, :on_turn_start, [turn, message, context])
    {:noreply, state}
  end

  def handle_cast({:on_session_end, messages, context}, state) do
    each_provider(state.providers, :on_session_end, [messages, context])
    {:noreply, state}
  end

  def handle_cast({:on_delegation, task, result, context}, state) do
    each_provider(state.providers, :on_delegation, [task, result, context])
    {:noreply, state}
  end

  defp configured_providers do
    [Vibe.Memory.BuiltinProvider | Application.get_env(:vibe, :memory_providers, [])]
    |> Enum.uniq()
  end

  defp start_provider(module, opts) do
    with {:ok, provider_state} <- module.init(opts) do
      {:ok,
       %{module: module, state: provider_state, external?: module != Vibe.Memory.BuiltinProvider}}
    end
  rescue
    exception -> {:error, exception}
  end

  defp call_join(providers, callback, args) do
    providers
    |> Enum.flat_map(fn provider ->
      case apply_provider(provider, callback, args) do
        text when is_binary(text) and text != "" -> [text]
        _ -> []
      end
    end)
    |> Enum.join("\n\n")
  end

  defp each_provider(providers, callback, args) do
    Enum.each(providers, &apply_provider(&1, callback, args))
  end

  defp append_provider(providers, provider), do: Lists.append(providers, provider)

  defp apply_provider(provider, callback, args) do
    apply(provider.module, callback, append_arg(args, provider.state))
  rescue
    _exception -> nil
  end

  defp append_arg(args, arg), do: Lists.append(args, arg)
end
