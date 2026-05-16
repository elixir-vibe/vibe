defmodule Vibe.Eval.Sandbox do
  @moduledoc """
  Sandboxed Elixir evaluation via Dune for untrusted input.

  Used by the web console eval widget and Telegram gateway where code
  comes from external users, not the agent. Restricts execution to safe
  modules/functions with memory and reduction limits.

  Requires the optional `dune` dependency. Returns `{:error, :unavailable}`
  when Dune is not installed.

  ## Custom allowlist

  The default allowlist permits standard library functions plus read-only
  Vibe introspection APIs. Configure additional modules:

      config :vibe, :sandbox_allowlist, MyApp.CustomAllowlist

  """

  @default_timeout_ms 5_000
  @default_max_reductions 50_000
  @default_max_heap_size 100_000

  @type result ::
          {:ok, %{value: term(), inspected: String.t(), stdio: String.t()}}
          | {:error, String.t()}
          | {:error, :unavailable}

  @spec available?() :: boolean()
  def available?, do: Code.ensure_loaded?(Dune)

  @spec eval(String.t(), keyword()) :: result()
  def eval(code, opts \\ []) when is_binary(code) do
    if available?() do
      do_eval(code, opts)
    else
      {:error, :unavailable}
    end
  end

  defp do_eval(code, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)
    max_reductions = Keyword.get(opts, :max_reductions, @default_max_reductions)
    max_heap_size = Keyword.get(opts, :max_heap_size, @default_max_heap_size)
    allowlist = Keyword.get(opts, :allowlist, configured_allowlist())

    dune_opts =
      [
        timeout: timeout,
        max_reductions: max_reductions,
        max_heap_size: max_heap_size
      ]
      |> maybe_put(:allowlist, allowlist)

    case Dune.eval_string(code, dune_opts) do
      %{__struct__: Dune.Success, value: value, inspected: inspected, stdio: stdio} ->
        {:ok, %{value: value, inspected: inspected, stdio: stdio}}

      %{__struct__: Dune.Failure, message: message} ->
        {:error, message}
    end
  end

  defp configured_allowlist do
    Application.get_env(:vibe, :sandbox_allowlist)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
