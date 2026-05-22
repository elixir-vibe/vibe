defmodule Vibe.CLI.Commands.Default.Dispatch do
  @moduledoc false

  @default_eval_timeout_ms 30_000

  @spec action([String.t()], keyword()) :: tuple()
  def action(args, opts) do
    cond do
      opts[:help] -> {:help}
      opts[:version] -> {:version}
      opts[:login] -> {:login, opts[:login]}
      opts[:web] -> {:web}
      code = opts[:eval] -> {:eval, code, opts[:timeout] || @default_eval_timeout_ms}
      opts[:compact] -> {:compact}
      opts[:checks] -> {:checks}
      opts[:codex_usage] -> {:codex_usage}
      opts[:sessions] -> {:sessions}
      opts[:bg] == true and args != [] -> {:background, Enum.join(args, " ")}
      opts[:print] == true or args != [] -> {:ask, split_file_args(args)}
      true -> {:attach_default}
    end
  end

  defp split_file_args(args) do
    {files, messages} = Enum.split_with(args, &String.starts_with?(&1, "@"))
    {Enum.map(files, &String.replace_prefix(&1, "@", "")), messages}
  end
end
