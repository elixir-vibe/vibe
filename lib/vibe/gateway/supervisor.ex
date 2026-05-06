defmodule Vibe.Gateway.Supervisor do
  @moduledoc """
  Supervisor for configured external gateway runtimes.

  Each gateway runs the generic `Vibe.Gateway.Runtime` with a backend module and
  optional backend-owned inbound transport children. Telegram polling/webhook
  can be added without changing the runtime or session dispatcher.
  """

  use Supervisor

  alias Vibe.Gateway.Runtime

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    Supervisor.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl true
  def init(opts) do
    opts
    |> Keyword.get(:gateways, [])
    |> Enum.flat_map(&gateway_children/1)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp gateway_children(opts) do
    id = Keyword.fetch!(opts, :id)
    backend = Keyword.fetch!(opts, :backend)
    config = load_config!(backend, opts)
    runtime_id = {:gateway_runtime, id}
    runtime_name = Keyword.get(opts, :runtime_name, runtime_name(id))

    runtime_child = %{
      id: runtime_id,
      start:
        {Runtime, :start_link,
         [
           [
             backend: backend,
             config: config,
             dispatch_fun: Keyword.get(opts, :dispatch_fun, &Vibe.Gateway.Dispatcher.dispatch/2),
             dispatch_opts: Keyword.get(opts, :dispatch_opts, []),
             name: runtime_name
           ]
         ]}
    }

    backend_children = backend_children(backend, config, runtime_name)

    [runtime_child | backend_children]
  end

  defp runtime_name(id), do: {:via, Registry, {Vibe.Registry, {:gateway_runtime, id}}}

  defp load_config!(backend, opts) do
    case Keyword.fetch(opts, :config) do
      {:ok, config} ->
        config

      :error ->
        backend_opts = Keyword.get(opts, :backend_opts, [])

        case backend.load_config(backend_opts) do
          {:ok, config} -> config
          {:error, reason} -> raise ArgumentError, "gateway config failed: #{inspect(reason)}"
        end
    end
  end

  defp backend_children(backend, config, runtime) do
    if function_exported?(backend, :child_specs, 2),
      do: backend.child_specs(config, runtime),
      else: []
  end
end
