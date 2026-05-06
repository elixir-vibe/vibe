defmodule Vibe.CLI.Parser do
  @moduledoc "CLI argv parser using OptionParser strict mode."
  @switches [
    help: :boolean,
    version: :boolean,
    model: :string,
    role: :string,
    cwd: :string,
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
    include_tools: :boolean,
    limit: :integer,
    no_fts: :boolean,
    rebuild_fts: :boolean,
    batch_size: :integer,
    overwrite: :boolean,
    web: :boolean,
    port: :integer,
    trace_tui: :string,
    frame: :integer,
    token: :string,
    bot_id: :string,
    bot_username: :string,
    allow_all: :boolean,
    allowed_users: :string,
    group_allowed_users: :string,
    group_allowed_chats: :string,
    require_mention: :boolean,
    free_response_chats: :string,
    stream_mode: :string
  ]

  @aliases [h: :help, v: :version, p: :print]

  @type parsed :: %{opts: keyword(), args: [String.t()], invalid: [{String.t(), term()}]}

  @spec parse([String.t()]) :: parsed()
  def parse(argv) do
    {opts, args, invalid} = OptionParser.parse(argv, strict: @switches, aliases: @aliases)
    %{opts: opts, args: args, invalid: invalid}
  end
end
