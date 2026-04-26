defmodule Exy.CLI do
  @moduledoc false

  alias Exy.CLI.{Output, Runner, Server, Sessions}

  @version Mix.Project.config()[:version]

  @switches [
    help: :boolean,
    version: :boolean,
    model: :string,
    api_key: :string,
    system_prompt: :string,
    mode: :string,
    print: :boolean,
    login: :string,
    eval: :string,
    compact: :boolean,
    keep_recent: :integer,
    checks: :boolean,
    codex_usage: :boolean,
    timeout: :integer,
    session: :string,
    sessions: :boolean,
    direct: :boolean,
    stream: :boolean,
    no_stream: :boolean,
    foreground: :boolean,
    all: :boolean,
    live: :boolean,
    failed: :boolean,
    limit: :integer
  ]

  @aliases [h: :help, v: :version, p: :print]

  def main(argv) do
    {opts, args, invalid} = parse(argv)

    cond do
      invalid == [] and match?(["server" | _], args) ->
        Server.command(tl(args), opts)

      invalid == [] and match?([command | _] when command in ["new", "n"], args) ->
        if opts[:print] == true or opts[:mode] == "json",
          do: Sessions.new(opts),
          else: Sessions.new_tui(opts)

      invalid == [] and match?([command | _] when command in ["sessions", "ls"], args) ->
        [_command | rest] = args
        Sessions.command(rest, opts)

      invalid == [] and match?(["send", _session_id | _], args) ->
        ["send", session_id | prompt_parts] = args

        Sessions.send_prompt(session_id, Enum.join(prompt_parts, " "), opts)

      invalid == [] and match?([command] when command in ["attach", "a"], args) ->
        Sessions.attach_default(opts)

      invalid == [] and match?([command, _session_id] when command in ["attach", "a"], args) ->
        [_command, session_id] = args
        Sessions.attach(session_id, opts)

      true ->
        main_options(opts, args, invalid)
    end
  end

  defp main_options(opts, args, invalid) do
    cond do
      invalid != [] ->
        Enum.each(invalid, fn {flag, _} -> Output.error("Unknown option: #{flag}") end)
        {:error, :invalid_args}

      opts[:help] ->
        Mix.Tasks.Help.run(["exy"])
        :ok

      opts[:version] ->
        IO.puts(@version)
        :ok

      opts[:login] ->
        login(opts[:login])

      code = opts[:eval] ->
        Output.print(Exy.Eval.once(code, timeout: opts[:timeout] || 30_000), opts)

      opts[:compact] ->
        compact(opts)

      opts[:checks] ->
        Output.print(Exy.Code.Checks.run_all(), opts)

      opts[:codex_usage] ->
        Output.print(Exy.Auth.Codex.usage_limits(), opts)

      opts[:sessions] ->
        Output.print({:ok, Exy.Session.Store.list()}, opts)

      opts[:print] == true or args != [] ->
        prompt = Enum.join(args, " ")
        Runner.ask(prompt, opts)

      true ->
        Sessions.attach_default(opts)
    end
  end

  @doc false
  def parse(argv) do
    OptionParser.parse(argv, strict: @switches, aliases: @aliases)
  end

  defp login(provider), do: Exy.Auth.login(provider)

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
