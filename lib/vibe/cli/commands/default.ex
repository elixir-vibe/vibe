defmodule Vibe.CLI.Commands.Default do
  @moduledoc "Default CLI entrypoint: prompt, TUI, eval, and flag dispatch."
  alias Vibe.CLI.{Output, Runner, Sessions}
  alias Vibe.Web

  @version Mix.Project.config()[:version]
  @default_eval_timeout_ms 30_000
  @default_web_port 4321

  @spec run([String.t()], keyword()) :: :ok | {:error, term()}
  def run(args, opts) do
    cond do
      opts[:help] ->
        Mix.Tasks.Help.run(["vibe"])
        :ok

      opts[:version] ->
        IO.puts(@version)
        :ok

      opts[:login] ->
        Vibe.Auth.login(opts[:login])

      opts[:web] ->
        web(opts)

      code = opts[:eval] ->
        Output.print(
          Vibe.Eval.once(code, timeout: opts[:timeout] || @default_eval_timeout_ms),
          opts
        )

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        Output.print(Vibe.Code.Checks.run_all(), opts)

      opts[:codex_usage] ->
        Output.print(Vibe.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        Output.print({:ok, Vibe.Session.Store.list()}, opts)

      opts[:print] == true or args != [] ->
        {file_args, message_args} = split_file_args(args)

        opts = Keyword.put(opts, :file_args, file_args)

        message_args
        |> Enum.join(" ")
        |> Runner.ask(opts)

      true ->
        Sessions.attach_default(opts)
    end
  end

  defp split_file_args(args) do
    {files, messages} = Enum.split_with(args, &String.starts_with?(&1, "@"))
    {Enum.map(files, &String.replace_prefix(&1, "@", "")), messages}
  end

  defp web(opts) do
    port = opts[:port] || @default_web_port

    case Web.start(port: port) do
      {:ok, _pid} ->
        IO.puts("Vibe web listening on #{Web.url(port: port)}")
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        IO.puts("Vibe web already listening on #{Web.url(port: port)}")
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

    Output.print(Vibe.Context.compact(opts), opts)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
