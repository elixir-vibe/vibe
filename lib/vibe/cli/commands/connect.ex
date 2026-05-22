defmodule Vibe.CLI.Commands.Connect do
  @moduledoc "CLI `connect` command: connect to a trusted remote Vibe node."
  @behaviour Vibe.CLI.Command

  alias Vibe.CLI.Output
  alias Vibe.CLI.Commands.Connect.{Dispatch, KnownNodesView}
  alias Vibe.Remote.KnownNodes
  alias Vibe.Remote.Transport.{Distribution, SSH}

  @impl true
  def names, do: ["connect"]

  @impl true
  def run(args, opts) do
    args
    |> Dispatch.action(opts)
    |> execute()
  end

  defp execute({:ssh, target, opts}), do: connect_ssh(target, opts)
  defp execute({:distribution, target}), do: connect_distribution(target)

  defp execute({:list_known_nodes}) do
    KnownNodes.list()
    |> KnownNodesView.render()
    |> IO.puts()

    :ok
  end

  defp execute({:invalid}) do
    Output.error("Usage: vibe connect --ssh <host:port> | vibe connect --dist <node@host>")
    {:error, :invalid_connect_command}
  end

  defp connect_ssh(target, opts) do
    with {:ok, {host, port}} <- parse_ssh_target(target, opts),
         {:ok, connection} <- Vibe.Remote.connect(ssh_connect_opts(host, port, opts)),
         {:ok, _pong} <- SSH.request(connection, %{"op" => "ping"}) do
      SSH.close(connection)
      KnownNodes.add("#{host}:#{port}", label: target, transport: "ssh")
      IO.puts("Connected to Vibe SSH endpoint #{host}:#{port}")
      IO.puts("Saved to known nodes.")
      :ok
    else
      {:error, reason} ->
        Output.error("Could not connect to #{target}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp ssh_connect_opts(host, port, opts) do
    [
      transport: :ssh,
      host: host,
      port: port,
      silently_accept_hosts: Keyword.get(opts, :yes, false)
    ]
    |> maybe_put(:password, opts[:password])
  end

  defp connect_distribution(target) do
    node = parse_node(target)

    case Distribution.connect_node(node) do
      {:ok, node} ->
        KnownNodes.add(Atom.to_string(node), label: target, transport: "distribution")
        IO.puts("Connected to trusted distribution node #{node}")
        IO.puts("Saved to known nodes.")
        :ok

      {:error, reason} ->
        Output.error("Could not connect to #{target}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_node(target) do
    target = if String.contains?(target, "@"), do: target, else: "#{target}@127.0.0.1"
    :erlang.binary_to_atom(target)
  end

  defp parse_ssh_target(target, opts) do
    uri = URI.parse(if String.contains?(target, "://"), do: target, else: "ssh://#{target}")
    port = uri.port || opts[:port]

    cond do
      is_nil(uri.host) or uri.host == "" -> {:error, :missing_ssh_host}
      is_nil(port) -> {:error, :missing_ssh_port}
      true -> {:ok, {uri.host, port}}
    end
  end
end
