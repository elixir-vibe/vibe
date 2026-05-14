defmodule Vibe.CLI.Commands.Connect do
  @moduledoc "CLI `connect` command: connect to a remote Vibe node."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Output
  alias Vibe.Remote.KnownNodes

  @impl true
  def names, do: ["connect"]

  @impl true
  def run(["connect", target], _opts) do
    node = parse_node(target)

    case connect_to(node) do
      {:ok, node} ->
        KnownNodes.add(Atom.to_string(node), label: target)
        IO.puts("Connected to #{node}")
        IO.puts("Saved to known nodes.")
        :ok

      {:error, reason} ->
        Output.error("Could not connect to #{target}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def run(["connect"], _opts) do
    nodes = KnownNodes.list()

    if nodes == [] do
      IO.puts("No known nodes. Usage: vibe connect node@host")
    else
      IO.puts("Known nodes:")

      Enum.each(nodes, fn entry ->
        label = if entry["label"], do: " (#{entry["label"]})", else: ""
        IO.puts("  #{entry["node"]}#{label}")
      end)
    end

    :ok
  end

  def run(_args, _opts) do
    Output.error("Usage: vibe connect <node@host>")
    {:error, :invalid_connect_command}
  end

  defp parse_node(target) do
    target = if String.contains?(target, "@"), do: target, else: "#{target}@127.0.0.1"
    String.to_atom(target)
  end

  defp connect_to(node) do
    cookie = Vibe.Server.Cookie.get()

    unless Node.alive?() do
      name =
        String.to_atom("vibe_connect_#{System.unique_integer([:positive])}@127.0.0.1")

      System.cmd("epmd", ["-daemon"])
      Node.start(name)
    end

    Node.set_cookie(cookie)

    if Node.connect(node) do
      {:ok, node}
    else
      {:error, :not_connected}
    end
  end
end
