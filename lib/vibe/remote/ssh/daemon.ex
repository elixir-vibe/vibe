defmodule Vibe.Remote.SSH.Daemon do
  @moduledoc "OTP SSH daemon for constrained remote Vibe operations."

  alias Vibe.Remote.SSH.{Keys, Protocol}

  @default_user "vibe"

  @type daemon_ref :: :ssh.daemon_ref()

  @spec start(keyword()) :: {:ok, daemon_ref()} | {:error, term()}
  def start(opts \\ []) do
    Application.ensure_all_started(:ssh)
    Keys.ensure_host_key!()

    port = Keyword.get(opts, :port, 0)
    user = Keyword.get(opts, :user, @default_user) |> to_charlist()
    password = Keyword.get_lazy(opts, :password, &Vibe.Server.Cookie.get/0) |> to_charlist()

    :ssh.daemon(port, daemon_options(user, password, opts))
  end

  @spec stop(daemon_ref()) :: :ok
  def stop(ref), do: :ssh.stop_daemon(ref)

  @spec info(daemon_ref()) :: {:ok, keyword()} | {:error, :bad_daemon_ref}
  def info(ref), do: :ssh.daemon_info(ref)

  @spec port(daemon_ref()) :: {:ok, non_neg_integer()} | {:error, term()}
  def port(ref) do
    case info(ref) do
      {:ok, info} -> {:ok, Keyword.fetch!(info, :port)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp daemon_options(user, password, opts) do
    [
      system_dir: Keys.system_dir() |> to_charlist(),
      user_passwords: [{user, password}],
      shell: :disabled,
      exec: {:direct, &exec/1},
      subsystems: []
    ]
    |> Keyword.merge(Keyword.get(opts, :ssh_options, []))
  end

  defp exec(command), do: Protocol.handle_exec(command)
end
