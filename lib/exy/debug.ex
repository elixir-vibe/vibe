defmodule Exy.Debug do
  @moduledoc """
  Compile-time gated debug hooks.

  Code wrapped in `run/1` is completely compiled out when
  `config :exy, :compile_time_debug` is false.
  """

  defmacro enabled? do
    debug_enabled?()
  end

  defmacro run(do: block) do
    if debug_enabled?() do
      block
    else
      quote(do: :ok)
    end
  end

  defmacro run(default, blocks) do
    block = Keyword.fetch!(blocks, :do)

    if debug_enabled?() do
      block
    else
      default
    end
  end

  defp debug_enabled? do
    Application.get_env(:exy, :compile_time_debug, false)
  end
end
