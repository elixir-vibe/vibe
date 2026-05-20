defmodule Vibe.Remote.SSH.Keys do
  @moduledoc "SSH host key management for the Vibe OTP SSH daemon."

  @spec system_dir() :: String.t()
  def system_dir, do: Path.join(Vibe.Paths.home(), "ssh")

  @spec host_key_path() :: String.t()
  def host_key_path, do: Path.join(system_dir(), "ssh_host_rsa_key")

  @spec ensure_host_key!() :: String.t()
  def ensure_host_key! do
    path = host_key_path()
    File.mkdir_p!(Path.dirname(path))

    unless File.exists?(path) do
      key = :public_key.generate_key({:rsa, 2048, 65_537})
      pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])
      File.write!(path, pem)
      File.chmod!(path, 0o600)
    end

    path
  end
end
