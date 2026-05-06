defmodule Vibe.UI.Error do
  @moduledoc "Semantic error payload shared by TUI, Web, previews, and persisted UI events."

  @enforce_keys [:message]
  defstruct [:kind, :message, :hint, :detail, :provider, retryable?: false]

  @type t :: %__MODULE__{
          kind: atom() | nil,
          message: String.t(),
          hint: String.t() | nil,
          detail: String.t() | nil,
          provider: atom() | String.t() | nil,
          retryable?: boolean()
        }

  @spec new(String.t(), keyword()) :: t()
  def new(message, opts \\ []) when is_binary(message) do
    %__MODULE__{
      kind: Keyword.get(opts, :kind),
      message: message,
      hint: Keyword.get(opts, :hint),
      detail: Keyword.get(opts, :detail),
      provider: Keyword.get(opts, :provider),
      retryable?: Keyword.get(opts, :retryable?, false)
    }
  end

  @spec message(t() | map() | String.t() | term()) :: String.t()
  def message(%__MODULE__{message: message}), do: message
  def message(%{message: message}) when is_binary(message), do: message
  def message(%{"message" => message}) when is_binary(message), do: message
  def message(message) when is_binary(message), do: message
  def message(error), do: inspect(error, limit: 4, printable_limit: 160)

  @spec text(t() | map() | String.t() | term()) :: String.t()
  def text(error) do
    case hint(error) do
      nil -> message(error)
      "" -> message(error)
      hint -> message(error) <> "\n" <> hint
    end
  end

  @spec hint(t() | map() | term()) :: String.t() | nil
  def hint(%__MODULE__{hint: hint}), do: hint
  def hint(%{hint: hint}) when is_binary(hint), do: hint
  def hint(%{"hint" => hint}) when is_binary(hint), do: hint
  def hint(_error), do: nil

  @spec detail(t() | map() | term()) :: String.t() | nil
  def detail(%__MODULE__{detail: detail}), do: detail
  def detail(%{detail: detail}) when is_binary(detail), do: detail
  def detail(%{"detail" => detail}) when is_binary(detail), do: detail
  def detail(_error), do: nil
end

defimpl Jason.Encoder, for: Vibe.UI.Error do
  def encode(error, opts) do
    error
    |> Map.from_struct()
    |> Vibe.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
