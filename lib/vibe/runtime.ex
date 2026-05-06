defmodule Vibe.Runtime do
  @moduledoc """
  Behaviour for stateful evaluation runtimes.
  """

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
end
