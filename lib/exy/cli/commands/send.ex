defmodule Exy.CLI.Commands.Send do
  @moduledoc false

  @behaviour Exy.CLI.Command

  alias Exy.CLI.Sessions

  @impl true
  def names, do: ["send"]

  @impl true
  def run(["send", session_id | prompt_parts], opts) do
    Sessions.send_prompt(session_id, Enum.join(prompt_parts, " "), opts)
  end

  def run(_args, _opts), do: {:error, :invalid_send_command}
end
