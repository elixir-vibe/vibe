defmodule Exy.JS do
  @moduledoc """
  Optional JavaScript/TypeScript evaluation through QuickBEAM.

  This is intentionally a helper module callable from `eval`, not a new
  model-facing tool.
  """

  @spec run(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def run(code, opts \\ []) when is_binary(code) do
    with :ok <- ensure_quickbeam(),
         {:ok, runtime} <- QuickBEAM.start(Keyword.get(opts, :runtime_opts, [])) do
      eval_fun =
        if Keyword.get(opts, :typescript, false),
          do: &QuickBEAM.eval_ts/3,
          else: &QuickBEAM.eval/3

      eval_fun.(runtime, code, Keyword.take(opts, [:timeout, :vars]))
    end
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end

  defp ensure_quickbeam do
    if Code.ensure_loaded?(QuickBEAM), do: :ok, else: {:error, :quickbeam_not_available}
  end
end
