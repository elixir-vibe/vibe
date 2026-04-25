defmodule Exy.Runtime do
  @moduledoc """
  Behaviour and facade for stateful evaluation runtimes.

  The default runtime is `Exy.Runtime.Standalone`, a Livebook-inspired separate
  BEAM OS process with a small line protocol and persistent evaluator context.
  """

  @type runtime_module :: module()
  @type locator :: GenServer.server() | {runtime_module(), GenServer.server()}
  @type eval_result :: %{
          status: :ok | :error | :timeout,
          value: term(),
          output: String.t(),
          diagnostics: [map()]
        }

  @callback start_link(keyword()) :: GenServer.on_start()
  @callback evaluate(GenServer.server(), String.t(), keyword()) ::
              {:ok, eval_result()} | {:error, term()}
  @callback stop(GenServer.server()) :: :ok

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    module = runtime_module(opts)

    case module.start_link(Keyword.delete(opts, :runtime)) do
      {:ok, runtime} -> {:ok, {module, runtime}}
      other -> other
    end
  end

  @spec evaluate(locator(), String.t(), keyword()) :: {:ok, eval_result()} | {:error, term()}
  def evaluate(runtime, code, opts \\ [])
  def evaluate({module, runtime}, code, opts), do: module.evaluate(runtime, code, opts)
  def evaluate(runtime, code, opts), do: Exy.Runtime.Standalone.evaluate(runtime, code, opts)

  @spec stop(locator()) :: :ok
  def stop({module, runtime}), do: module.stop(runtime)
  def stop(runtime), do: Exy.Runtime.Standalone.stop(runtime)

  defp runtime_module(opts), do: Keyword.get(opts, :runtime, Exy.Runtime.Standalone)
end
