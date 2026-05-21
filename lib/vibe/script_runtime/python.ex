defmodule Vibe.ScriptRuntime.Python do
  @moduledoc """
  Optional Python evaluation through Pythonx.

  This is intentionally a helper module callable from `eval`, not a new
  model-facing tool.
  """

  @spec run(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(code, globals \\ %{}, opts \\ []) when is_binary(code) and is_map(globals) do
    with :ok <- ensure_pythonx() do
      if opts[:uv_init] do
        Pythonx.uv_init(opts[:uv_init], Keyword.get(opts, :uv_opts, []))
      else
        Application.ensure_all_started(:pythonx)
      end

      {result, globals} =
        Pythonx.eval(code, globals, Keyword.take(opts, [:stdout_device, :stderr_device]))

      {:ok, %{result: result, globals: globals}}
    end
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end

  defp ensure_pythonx do
    if Code.ensure_loaded?(Pythonx), do: :ok, else: {:error, :pythonx_not_available}
  end
end
