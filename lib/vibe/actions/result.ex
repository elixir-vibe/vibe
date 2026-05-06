defmodule Vibe.Actions.Result do
  @moduledoc "Shared tool result formatting."
  @type t :: {:ok, term()} | {:error, term()}

  @spec run((-> t() | term())) :: t()
  def run(fun) when is_function(fun, 0) do
    case fun.() do
      {:ok, _result} = ok -> ok
      {:error, _reason} = error -> error
      result -> {:ok, result}
    end
  rescue
    error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
  catch
    kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
  end
end
