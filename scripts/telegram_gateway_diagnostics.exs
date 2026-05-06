defmodule Exy.TelegramDiagnosticsAdapter do
  @behaviour Exy.Gateway.Adapter

  @impl true
  def send(chat_id, text, opts) do
    owner = Keyword.fetch!(opts, :owner)
    send(owner, {:gateway_send, chat_id, text, sanitize_opts(opts)})
    {:ok, "diagnostic-message"}
  end

  @impl true
  def edit(chat_id, message_id, text, opts) do
    owner = Keyword.fetch!(opts, :owner)
    send(owner, {:gateway_edit, chat_id, message_id, text, sanitize_opts(opts)})
    {:ok, message_id}
  end

  defp sanitize_opts(opts) do
    Keyword.update(opts, :config, nil, fn
      %{token: _token} = config -> %{config | token: "[redacted]"}
      config -> config
    end)
  end
end

Mix.Task.run("app.start")

alias Exy.Gateway.Runtime

token = System.fetch_env!("TELEGRAM_BOT_TOKEN")
chat_id = System.get_env("TELEGRAM_DIAGNOSTIC_CHAT_ID")
bot_username = System.get_env("TELEGRAM_BOT_USERNAME", "dannote_bot")
bot_id = System.get_env("TELEGRAM_BOT_ID", "8493391913")

IO.puts("Telegram gateway diagnostics")

IO.inspect(ExGram.get_me(token: token), label: "get_me")
IO.inspect(ExGram.get_webhook_info(token: token), label: "webhook")

IO.inspect(ExGram.get_updates(limit: 1, timeout: 1, receive_timeout: 5_000, token: token),
  label: "single_get_updates"
)

config = %Exy.Gateway.Telegram.Config{
  token: token,
  bot_id: bot_id,
  bot_username: bot_username,
  allow_all?: true,
  stream_mode: :edit
}

{:ok, runtime} =
  Runtime.start_link(
    backend: Exy.Gateway.Telegram.Backend,
    config: config,
    dispatch_opts: [
      session_opts: [ask_fun: fn prompt, _opts -> {:ok, "diagnostic response: #{prompt}"} end],
      bridge_adapter: Exy.TelegramDiagnosticsAdapter,
      bridge_adapter_opts: [owner: self()]
    ]
  )

update = %{
  update_id: System.unique_integer([:positive]),
  message: %{
    message_id: System.unique_integer([:positive]),
    text: "synthetic runtime update",
    chat: %{id: 155_035_264, type: "private"},
    from: %{id: 155_035_264, first_name: "Diagnostic"}
  }
}

Runtime.submit(runtime, update)
Process.sleep(1_000)
IO.inspect(Runtime.stats(runtime), label: "synthetic_runtime_stats")

receive do
  event -> IO.inspect(event, label: "synthetic_bridge_event")
after
  1_000 -> IO.puts("synthetic_bridge_event: none")
end

if chat_id do
  parsed_chat_id = String.to_integer(chat_id)

  IO.inspect(
    ExGram.send_message(parsed_chat_id, "Exy Telegram diagnostics outbound smoke", token: token),
    label: "real_outbound_smoke"
  )

  IO.inspect(
    ExGram.send_message_draft(
      parsed_chat_id,
      System.unique_integer([:positive]),
      "Exy Telegram diagnostics draft smoke",
      token: token
    ),
    label: "real_draft_smoke"
  )
end
