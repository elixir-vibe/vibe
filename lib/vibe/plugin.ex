defmodule Vibe.Plugin do
  @moduledoc """
  Behaviour for Vibe plugins.

  Plugins are BEAM modules, not model-facing tools by default. They can observe
  lifecycle events, expose supervised children, register slash commands, provide
  eval APIs, add model-facing actions, and update renderer-neutral UI state.

  Use plugin APIs when a capability should be composable from `Vibe.Eval`; expose
  model-facing actions only when the model needs direct tool access.
  """

  alias Vibe.Plugin.API
  alias Vibe.UI.Document

  @type event :: %{required(:type) => atom(), optional(atom()) => term()}
  @type context :: map()
  @type result :: :ok | {:ok, map()} | {:error, term()} | {:halt, term()}

  @callback init(keyword()) :: {:ok, term()} | {:error, term()}
  @callback handle_event(event(), context(), term()) :: {result(), term()}
  @callback system_prompt(context(), term()) :: {String.t() | nil, term()}
  @callback before_command(String.t(), context(), term()) ::
              {:ok, term()} | {:warn, String.t(), term()} | {:block, String.t(), term()}
  @callback tool_call(map(), context(), term()) ::
              {:ok, term()} | {:ok, map(), term()} | {:block, String.t(), term()}
  @callback tool_result(map(), context(), term()) :: {:ok, term()} | {:ok, map(), term()}
  @callback context(list(), context(), term()) :: {:ok, term()} | {:ok, list(), term()}
  @callback actions(term()) :: [module()]
  @callback commands(term()) :: [module() | map()]
  @callback apis(term()) :: [API.t() | keyword() | map()]
  @callback children(term()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback children(term(), map()) :: [Supervisor.child_spec() | {module(), term()} | module()]
  @callback ui_document(term()) :: Document.t() | keyword() | map()
  @callback shutdown(term()) :: :ok

  @optional_callbacks system_prompt: 2,
                      before_command: 3,
                      tool_call: 3,
                      tool_result: 3,
                      context: 3,
                      actions: 1,
                      commands: 1,
                      apis: 1,
                      children: 1,
                      children: 2,
                      ui_document: 1,
                      shutdown: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Vibe.Plugin
      Module.register_attribute(__MODULE__, :vibe_plugin_apis, accumulate: true)

      import Vibe.Plugin, only: [api: 1]

      @before_compile Vibe.Plugin

      @impl Vibe.Plugin
      def init(opts), do: {:ok, opts}

      @impl Vibe.Plugin
      def handle_event(_event, _context, state), do: {:ok, state}

      @impl Vibe.Plugin
      def system_prompt(_context, state), do: {nil, state}

      @impl Vibe.Plugin
      def before_command(_command, _context, state), do: {:ok, state}

      @impl Vibe.Plugin
      def tool_call(_call, _context, state), do: {:ok, state}

      @impl Vibe.Plugin
      def tool_result(_result, _context, state), do: {:ok, state}

      @impl Vibe.Plugin
      def context(_messages, _context, state), do: {:ok, state}

      @impl Vibe.Plugin
      def actions(_state), do: []

      @impl Vibe.Plugin
      def commands(_state), do: []

      @impl Vibe.Plugin
      def apis(_state), do: __vibe_plugin_apis__()

      @impl Vibe.Plugin
      def children(_state), do: []

      @impl Vibe.Plugin
      def children(state, _context), do: children(state)

      @impl Vibe.Plugin
      def ui_document(_state), do: Vibe.UI.Document.empty()

      @impl Vibe.Plugin
      def shutdown(_state), do: :ok

      defoverridable init: 1,
                     handle_event: 3,
                     system_prompt: 2,
                     before_command: 3,
                     tool_call: 3,
                     tool_result: 3,
                     context: 3,
                     actions: 1,
                     commands: 1,
                     apis: 1,
                     children: 1,
                     children: 2,
                     ui_document: 1,
                     shutdown: 1
    end
  end

  defmacro api(attrs) do
    attrs = expand_api_attrs(attrs, __CALLER__)

    quote do
      @vibe_plugin_apis unquote(Macro.escape(attrs))
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
      |> Module.get_attribute(:vibe_plugin_apis)
      |> Enum.reverse()

    quote do
      def __vibe_plugin_apis__ do
        unquote(Macro.escape(apis))
        |> Enum.map(&Vibe.Plugin.API.new/1)
      end
    end
  end
end
