defmodule Exy.Gateway.Telegram.Config do
  @moduledoc """
  Runtime configuration for the Telegram gateway.

  Values come from application env first and environment variables second so the
  gateway can be configured in releases without recompilation while remaining
  easy to exercise in tests.
  """

  @enforce_keys [:token]
  defstruct token: nil,
            bot_id: nil,
            bot_username: nil,
            method: :polling,
            webhook_url: nil,
            webhook_secret: nil,
            allowed_users: MapSet.new(),
            group_allowed_users: MapSet.new(),
            group_allowed_chats: MapSet.new(),
            allow_all?: false,
            require_mention?: false,
            free_response_chats: MapSet.new(),
            ignored_threads: MapSet.new(),
            edit_interval_ms: 1_000,
            buffer_threshold: 40,
            stream_mode: :edit

  @type method :: :polling | :webhook

  @type t :: %__MODULE__{
          token: String.t(),
          bot_id: String.t() | nil,
          bot_username: String.t() | nil,
          method: method(),
          webhook_url: String.t() | nil,
          webhook_secret: String.t() | nil,
          allowed_users: MapSet.t(String.t()),
          group_allowed_users: MapSet.t(String.t()),
          group_allowed_chats: MapSet.t(String.t()),
          allow_all?: boolean(),
          require_mention?: boolean(),
          free_response_chats: MapSet.t(String.t()),
          ignored_threads: MapSet.t(String.t()),
          edit_interval_ms: pos_integer(),
          buffer_threshold: pos_integer(),
          stream_mode: :edit | :draft | :auto
        }

  @doc "Loads Telegram gateway config from application/env settings."
  @spec load(keyword()) :: {:ok, t()} | {:error, term()}
  def load(overrides \\ []) do
    with {:ok, token} <- fetch_token(overrides),
         {:ok, method} <- method(overrides),
         {:ok, webhook_secret} <- webhook_secret(method, overrides) do
      {:ok,
       %__MODULE__{
         token: token,
         bot_id: optional_string(setting(overrides, :bot_id, "TELEGRAM_BOT_ID")),
         bot_username:
           optional_string(setting(overrides, :bot_username, "TELEGRAM_BOT_USERNAME")),
         method: method,
         webhook_url: setting(overrides, :webhook_url, "TELEGRAM_WEBHOOK_URL"),
         webhook_secret: webhook_secret,
         allowed_users: csv_set(setting(overrides, :allowed_users, "TELEGRAM_ALLOWED_USERS")),
         group_allowed_users:
           csv_set(setting(overrides, :group_allowed_users, "TELEGRAM_GROUP_ALLOWED_USERS")),
         group_allowed_chats:
           csv_set(setting(overrides, :group_allowed_chats, "TELEGRAM_GROUP_ALLOWED_CHATS")),
         allow_all?: bool(setting(overrides, :allow_all?, "TELEGRAM_ALLOW_ALL_USERS")),
         require_mention?:
           bool(setting(overrides, :require_mention?, "TELEGRAM_REQUIRE_MENTION")),
         free_response_chats:
           csv_set(setting(overrides, :free_response_chats, "TELEGRAM_FREE_RESPONSE_CHATS")),
         ignored_threads:
           int_set(setting(overrides, :ignored_threads, "TELEGRAM_IGNORED_THREADS")),
         edit_interval_ms:
           integer_setting(overrides, :edit_interval_ms, "TELEGRAM_EDIT_INTERVAL_MS", 1_000),
         buffer_threshold:
           integer_setting(overrides, :buffer_threshold, "TELEGRAM_BUFFER_THRESHOLD", 40),
         stream_mode: stream_mode(setting(overrides, :stream_mode, "TELEGRAM_STREAM_MODE"))
       }}
    end
  end

  defp fetch_token(overrides) do
    case setting(overrides, :token, "TELEGRAM_BOT_TOKEN") do
      token when is_binary(token) and token != "" -> {:ok, token}
      _missing -> {:error, :telegram_token_required}
    end
  end

  defp method(overrides) do
    case setting(overrides, :method, "TELEGRAM_METHOD") do
      value when value in [:polling, :webhook] ->
        {:ok, value}

      "polling" ->
        {:ok, :polling}

      "webhook" ->
        {:ok, :webhook}

      nil ->
        if(setting(overrides, :webhook_url, "TELEGRAM_WEBHOOK_URL"),
          do: {:ok, :webhook},
          else: {:ok, :polling}
        )

      other ->
        {:error, {:invalid_telegram_method, other}}
    end
  end

  defp webhook_secret(:polling, _overrides), do: {:ok, nil}

  defp webhook_secret(:webhook, overrides) do
    case setting(overrides, :webhook_secret, "TELEGRAM_WEBHOOK_SECRET") do
      secret when is_binary(secret) and byte_size(secret) >= 16 -> {:ok, secret}
      _missing -> {:error, :telegram_webhook_secret_required}
    end
  end

  defp setting(overrides, key, env) do
    Keyword.get(overrides, key) ||
      Application.get_env(:exy, telegram_env_key(key)) ||
      System.get_env(env)
  end

  defp telegram_env_key(key), do: String.to_atom("telegram_#{key}")

  defp csv_set(nil), do: MapSet.new()
  defp csv_set(values) when is_list(values), do: values |> Enum.map(&to_string/1) |> MapSet.new()

  defp csv_set(values) do
    values
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> MapSet.new()
  end

  defp int_set(nil), do: MapSet.new()
  defp int_set(values), do: values |> csv_set() |> Enum.flat_map(&parse_int/1) |> MapSet.new()

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> [int]
      _other -> []
    end
  end

  defp stream_mode(value) when value in [:edit, :draft, :auto], do: value
  defp stream_mode("edit"), do: :edit
  defp stream_mode("draft"), do: :draft
  defp stream_mode("auto"), do: :auto
  defp stream_mode(_value), do: :edit

  defp optional_string(nil), do: nil
  defp optional_string(""), do: nil
  defp optional_string(value) when is_binary(value), do: value
  defp optional_string(value), do: to_string(value)

  defp bool(value) when value in [true, false], do: value
  defp bool(nil), do: false
  defp bool(value), do: String.downcase(to_string(value)) in ["1", "true", "yes", "on"]

  defp integer_setting(overrides, key, env, default) do
    case setting(overrides, key, env) do
      value when is_integer(value) and value > 0 -> value
      value when is_binary(value) -> parse_positive_integer(value, default)
      _other -> default
    end
  end

  defp parse_positive_integer(value, default) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> int
      _other -> default
    end
  end
end
