Logger.configure(level: :warning)

ExUnit.start(exclude: [integration: true], capture_log: true)

Application.put_env(:vibe, :terminal_notifications, false)
