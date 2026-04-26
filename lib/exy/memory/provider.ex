defmodule Exy.Memory.Provider do
  @moduledoc """
  Behaviour for memory providers managed by `Exy.Memory.Manager`.
  """

  @type context :: map()

  @callback init(keyword()) :: {:ok, term()} | {:error, term()}
  @callback system_prompt_block(term()) :: String.t()
  @callback prefetch(String.t(), context(), term()) :: String.t()
  @callback sync_turn(String.t(), String.t(), context(), term()) :: :ok
  @callback on_turn_start(non_neg_integer(), String.t(), context(), term()) :: :ok
  @callback on_session_end([map()], context(), term()) :: :ok
  @callback on_pre_compress([map()], context(), term()) :: String.t()
  @callback on_delegation(String.t(), String.t(), context(), term()) :: :ok
  @callback shutdown(term()) :: :ok

  @optional_callbacks system_prompt_block: 1,
                      prefetch: 3,
                      sync_turn: 4,
                      on_turn_start: 4,
                      on_session_end: 3,
                      on_pre_compress: 3,
                      on_delegation: 4,
                      shutdown: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Exy.Memory.Provider

      @impl Exy.Memory.Provider
      def init(opts), do: {:ok, opts}

      @impl Exy.Memory.Provider
      def system_prompt_block(_state), do: ""

      @impl Exy.Memory.Provider
      def prefetch(_query, _context, _state), do: ""

      @impl Exy.Memory.Provider
      def sync_turn(_user, _assistant, _context, _state), do: :ok

      @impl Exy.Memory.Provider
      def on_turn_start(_turn, _message, _context, _state), do: :ok

      @impl Exy.Memory.Provider
      def on_session_end(_messages, _context, _state), do: :ok

      @impl Exy.Memory.Provider
      def on_pre_compress(_messages, _context, _state), do: ""

      @impl Exy.Memory.Provider
      def on_delegation(_task, _result, _context, _state), do: :ok

      @impl Exy.Memory.Provider
      def shutdown(_state), do: :ok

      defoverridable init: 1,
                     system_prompt_block: 1,
                     prefetch: 3,
                     sync_turn: 4,
                     on_turn_start: 4,
                     on_session_end: 3,
                     on_pre_compress: 3,
                     on_delegation: 4,
                     shutdown: 1
    end
  end
end
