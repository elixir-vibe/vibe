defmodule Exy.Eval do
  @moduledoc """
  Runtime Elixir evaluation with captured IO and timeouts.

  This is Exy's primary power tool. Prefer adding helper modules callable from
  here over growing the external tool list.
  """

  @inspect_opts [charlists: :as_lists, limit: 80, pretty: true]

  @type result :: {:ok, String.t()} | {:error, String.t()}

  @spec run(String.t(), keyword()) :: result()
  def run(code, opts \\ []) when is_binary(code) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    caller = self()

    {pid, ref} =
      spawn_monitor(fn ->
        send(caller, {:exy_eval_result, self(), eval_with_captured_io(code)})
      end)

    receive do
      {:exy_eval_result, ^pid, result} ->
        Process.demonitor(ref, [:flush])
        result

      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error, "evaluation process exited: #{Exception.format_exit(reason)}"}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :brutal_kill)
        {:error, "evaluation timed out after #{timeout}ms"}
    end
  end

  defp eval_with_captured_io(code) do
    {{success?, result}, io} = capture_io(fn -> eval_code(code) end)

    cond do
      success? and result == :__exy_no_output__ ->
        {:ok, Exy.ToolOutput.limit_text(io)}

      success? and io == "" ->
        {:ok, result |> inspect(@inspect_opts) |> Exy.ToolOutput.limit_text()}

      success? ->
        {:ok,
         Exy.ToolOutput.limit_text("IO:\n\n#{io}\n\nResult:\n\n#{inspect(result, @inspect_opts)}")}

      true ->
        {:error, Exy.ToolOutput.limit_text(result)}
    end
  end

  defp eval_code(code) do
    try do
      {result, _bindings} = Code.eval_string(code, [], env())
      {true, result}
    catch
      kind, reason -> {false, Exception.format(kind, reason, __STACKTRACE__)}
    end
  end

  defp env do
    import IEx.Helpers, warn: false
    __ENV__
  end

  defp capture_io(fun) do
    {:ok, io} = StringIO.open("")
    ansi? = Application.get_env(:elixir, :ansi_enabled)
    original_gl = Process.group_leader()

    Application.put_env(:elixir, :ansi_enabled, false)
    Process.group_leader(self(), io)

    try do
      result = fun.()
      {_, content} = StringIO.contents(io)
      {result, content}
    after
      Process.group_leader(self(), original_gl)
      StringIO.close(io)
      Application.put_env(:elixir, :ansi_enabled, ansi?)
    end
  end
end
