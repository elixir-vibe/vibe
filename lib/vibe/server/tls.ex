defmodule Vibe.Server.TLS do
  @moduledoc """
  TLS certificate management for Erlang distribution.

  Generates a self-signed CA and per-node certificates on first run.
  Two Vibe instances trust each other if they share the same CA — copy
  `~/.vibe/tls/ca.pem` to establish trust between machines.

  Writes an `inet_tls_dist` option file that configures mutual TLS
  for Erlang distribution with `verify_peer`.
  """

  @tls_dir "tls"
  @ca_validity_days 3650
  @node_validity_days 3650
  @openssl System.find_executable("openssl") || "openssl"

  @spec tls_dir() :: String.t()
  def tls_dir, do: Path.join(Vibe.Paths.home(), @tls_dir)

  @spec ensure!() :: :ok
  def ensure! do
    dir = tls_dir()
    File.mkdir_p!(dir)

    unless File.exists?(ca_cert_path()) do
      generate_ca!(dir)
    end

    unless File.exists?(node_cert_path()) do
      generate_node_cert!(dir)
    end

    write_dist_config!(dir)
    :ok
  end

  @spec ca_cert_path() :: String.t()
  def ca_cert_path, do: Path.join(tls_dir(), "ca.pem")

  @spec ca_key_path() :: String.t()
  def ca_key_path, do: Path.join(tls_dir(), "ca-key.pem")

  @spec node_cert_path() :: String.t()
  def node_cert_path, do: Path.join(tls_dir(), "node.pem")

  @spec node_key_path() :: String.t()
  def node_key_path, do: Path.join(tls_dir(), "node-key.pem")

  @spec dist_config_path() :: String.t()
  def dist_config_path, do: Path.join(tls_dir(), "dist.conf")

  @spec dist_args() :: [String.t()]
  def dist_args do
    ensure!()
    ["-proto_dist", "inet_tls", "-ssl_dist_optfile", dist_config_path()]
  end

  defp generate_ca!(dir) do
    key = Path.join(dir, "ca-key.pem")
    cert = Path.join(dir, "ca.pem")

    openssl!(["genrsa", "-out", key, "2048"])
    File.chmod!(key, 0o600)

    openssl!([
      "req",
      "-x509",
      "-new",
      "-key",
      key,
      "-out",
      cert,
      "-days",
      to_string(@ca_validity_days),
      "-subj",
      "/CN=Vibe CA"
    ])
  end

  defp generate_node_cert!(dir) do
    key = Path.join(dir, "node-key.pem")
    csr = Path.join(dir, "node.csr")
    cert = Path.join(dir, "node.pem")

    hostname = hostname()

    openssl!(["genrsa", "-out", key, "2048"])
    File.chmod!(key, 0o600)

    openssl!(["req", "-new", "-key", key, "-out", csr, "-subj", "/CN=#{hostname}"])

    openssl!([
      "x509",
      "-req",
      "-in",
      csr,
      "-CA",
      ca_cert_path(),
      "-CAkey",
      ca_key_path(),
      "-CAcreateserial",
      "-out",
      cert,
      "-days",
      to_string(@node_validity_days)
    ])

    File.rm(csr)
    File.rm(Path.join(dir, "ca.srl"))
  end

  defp write_dist_config!(dir) do
    config = """
    [{server, [
      {certfile, "#{node_cert_path()}"},
      {keyfile, "#{node_key_path()}"},
      {cacertfile, "#{ca_cert_path()}"},
      {verify, verify_peer},
      {fail_if_no_peer_cert, true}
    ]},
    {client, [
      {certfile, "#{node_cert_path()}"},
      {keyfile, "#{node_key_path()}"},
      {cacertfile, "#{ca_cert_path()}"},
      {verify, verify_peer},
      {server_name_indication, disable}
    ]}].
    """

    Path.join(dir, "dist.conf") |> File.write!(config)
  end

  defp openssl!(args) do
    case System.cmd(@openssl, args, stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, code} -> raise "openssl #{Enum.join(args, " ")} failed (#{code}): #{output}"
    end
  end

  defp hostname do
    {:ok, name} = :inet.gethostname()
    to_string(name)
  end
end
