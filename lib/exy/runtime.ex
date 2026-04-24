defmodule Exy.Runtime do
  @moduledoc """
  Behaviour and facade for stateful evaluation runtimes.

  The default runtime is `Exy.Runtime.Standalone`, a Livebook-inspired separate
  BEAM OS process with a small line protocol and persistent evaluator context.
  """

  @type locator :: term()
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
  def start_link(opts \\ []), do: Exy.Runtime.Standalone.start_link(opts)

  @spec evaluate(GenServer.server(), String.t(), keyword()) ::
          {:ok, eval_result()} | {:error, term()}
  def evaluate(runtime, code, opts \\ []),
    do: Exy.Runtime.Standalone.evaluate(runtime, code, opts)

  @spec stop(GenServer.server()) :: :ok
  def stop(runtime), do: Exy.Runtime.Standalone.stop(runtime)
end
