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
  @callback commands(term()) :: [module() | map()]
  @callback apis(term()) :: [Exy.Plugin.API.t() | keyword() | map()]
  @callback children(term()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback children(term(), map()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback shutdown(term()) :: :ok

  @optional_callbacks actions: 1, commands: 1, apis: 1, children: 1, children: 2, shutdown: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Exy.Plugin
      Module.register_attribute(__MODULE__, :exy_plugin_apis, accumulate: true)

      import Exy.Plugin, only: [api: 1]

      @before_compile Exy.Plugin

      @impl Exy.Plugin
      def init(opts), do: {:ok, opts}

      @impl Exy.Plugin
      def handle_event(_event, _context, state), do: {:ok, state}

      @impl Exy.Plugin
      def actions(_state), do: []

      @impl Exy.Plugin
      def commands(_state), do: []

      @impl Exy.Plugin
      def apis(_state), do: __exy_plugin_apis__()

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
                     apis: 1,
                     children: 1,
                     children: 2,
                     shutdown: 1
    end
  end

  defmacro api(attrs) do
    attrs = expand_api_attrs(attrs, __CALLER__)

    quote do
      @exy_plugin_apis unquote(Macro.escape(attrs))
    end
  end

  defp expand_api_attrs(attrs, caller) do
    Enum.map(attrs, fn
      {key, value} when key in [:module, :alias] -> {key, Macro.expand(value, caller)}
      entry -> entry
    end)
  end

  defmacro __before_compile__(env) do
    apis =
      env.module
      |> Module.get_attribute(:exy_plugin_apis)
      |> Enum.reverse()

    quote do
      def __exy_plugin_apis__ do
        unquote(Macro.escape(apis))
        |> Enum.map(&Exy.Plugin.API.new/1)
      end
    end
  end
end
