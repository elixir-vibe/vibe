defmodule Exy.CLI.Commands.Attach do
  @moduledoc "CLI `attach` command: connect to a live session."
  @behaviour Exy.CLI.Command

  alias Exy.CLI.Sessions

  @impl true
  def names, do: ["attach", "a"]

  @impl true
  def run([_command], opts), do: Sessions.attach_default(opts)

  def run([_command, session_id], opts), do: Sessions.attach(session_id, opts)

  def run(_args, _opts), do: {:error, :invalid_attach_command}
end
