defmodule Exy.CLI.Commands.Default do
  @moduledoc false

  alias Exy.CLI.{Output, Runner, Sessions}
  alias Exy.Web

  @version Mix.Project.config()[:version]
  @default_eval_timeout_ms 30_000
  @default_web_port 4321

  @spec run([String.t()], keyword()) :: :ok | {:error, term()}
  def run(args, opts) do
    cond do
      opts[:help] ->
        Mix.Tasks.Help.run(["exy"])
        :ok

      opts[:version] ->
        IO.puts(@version)
        :ok

      opts[:login] ->
        Exy.Auth.login(opts[:login])

      opts[:web] ->
        web(opts)

      code = opts[:eval] ->
        Output.print(
          Exy.Eval.once(code, timeout: opts[:timeout] || @default_eval_timeout_ms),
          opts
        )

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        Output.print(Exy.Code.Checks.run_all(), opts)

      opts[:codex_usage] ->
        Output.print(Exy.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        Output.print({:ok, Exy.Session.Store.list()}, opts)

      opts[:print] == true or args != [] ->
        args
        |> Enum.join(" ")
        |> Runner.ask(opts)

      true ->
        Sessions.attach_default(opts)
    end
  end

  defp web(opts) do
    port = opts[:port] || @default_web_port

    case Web.start(port: port) do
      {:ok, _pid} ->
        IO.puts("Exy web listening on #{Web.url(port: port)}")
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        IO.puts("Exy web already listening on #{Web.url(port: port)}")
        Process.sleep(:infinity)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compact(opts) do
    opts =
      opts
      |> maybe_put(:keep_recent, opts[:keep_recent])
      |> maybe_put(:model, opts[:model])

    Output.print(Exy.Context.compact(opts), opts)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
