defmodule Vibe.CLI.Boot do
  @moduledoc false

  @spec configure_application_start(Vibe.CLI.Parser.parsed()) :: :ok
  def configure_application_start(parsed) do
    maybe_configure_web_port(parsed)
    Application.put_env(:vibe, :web, server_foreground?(parsed))
    :ok
  end

  @spec server_foreground?(Vibe.CLI.Parser.parsed()) :: boolean()
  def server_foreground?(%{args: ["server", command | _], opts: opts})
      when command in ["start", "restart"] do
    opts[:foreground] == true
  end

  def server_foreground?(_parsed), do: false

  defp maybe_configure_web_port(%{opts: opts}) do
    if port = opts[:port] do
      Application.put_env(:vibe, :web_port, port)
    end
  end

  defp maybe_configure_web_port(_parsed), do: :ok
end
