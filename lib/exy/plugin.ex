defmodule Exy.Plugin do
  @moduledoc """
  Behaviour for Exy plugins.

  Plugins are BEAM modules, not model-facing tools by default. They can observe
  lifecycle events, veto/alter selected events, and expose actions/commands that
  the host may choose to wire into CLI, TUI, or Jido.
  """

  @type event :: %{required(:type) => atom(), optional(atom()) => term()}
  @type context :: map()
  @type result :: :ok | {:ok, map()} | {:error, term()} | {:halt, term()}

  @callback init(keyword()) :: {:ok, term()} | {:error, term()}
  @callback handle_event(event(), context(), term()) :: {result(), term()}
  @callback actions(term()) :: [module()]
  @callback commands(term()) :: [map()]
  @callback children(term()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback children(term(), map()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback shutdown(term()) :: :ok

  @optional_callbacks actions: 1, commands: 1, children: 1, children: 2, shutdown: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Exy.Plugin

      @impl Exy.Plugin
      def init(opts), do: {:ok, opts}

      @impl Exy.Plugin
      def handle_event(_event, _context, state), do: {:ok, state}

      @impl Exy.Plugin
      def actions(_state), do: []

      @impl Exy.Plugin
      def commands(_state), do: []

      @impl Exy.Plugin
      def children(_state), do: []

      @impl Exy.Plugin
      def children(state, _context), do: children(state)

      @impl Exy.Plugin
      def shutdown(_state), do: :ok

      defoverridable init: 1,
                     handle_event: 3,
                     actions: 1,
                     commands: 1,
                     children: 1,
                     children: 2,
                     shutdown: 1
    end
  end
end
