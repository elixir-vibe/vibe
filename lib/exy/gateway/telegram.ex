defmodule Exy.Gateway.Telegram do
  @moduledoc """
  Convenience API for starting the Telegram gateway backend.

  The generic gateway runtime and supervisor remain backend-neutral; this module
  provides a small Telegram-specific entrypoint for CLI and future server config
  surfaces.
  """

  alias Exy.Gateway.Telegram.Backend

  @doc "Starts a foreground Telegram polling gateway under Exy's top-level supervisor."
  @spec start_polling(keyword()) :: Supervisor.on_start_child()
  def start_polling(opts \\ []) do
    opts = Keyword.put(opts, :method, :polling)

    Supervisor.start_child(Exy.Supervisor, {
      Exy.Gateway.Supervisor,
      gateways: [
        [
          id: :telegram,
          backend: Backend,
          backend_opts: opts
        ]
      ],
      name: Exy.Gateway.Telegram.Supervisor
    })
  end
end
