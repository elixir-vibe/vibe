defmodule Vibe.Jido do
  @moduledoc "Jido agent server lifecycle bridge."
  use Jido, otp_app: :vibe

  def config(overrides) do
    [
      telemetry: [log_level: :error, log_args: :none],
      observability: [log_level: :warning]
    ]
    |> Keyword.merge(Application.get_env(:vibe, __MODULE__, []))
    |> Keyword.merge(overrides)
  end
end
