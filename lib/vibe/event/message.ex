defmodule Vibe.Event.Message do
  @moduledoc "Typed semantic message event payloads."

  defmodule UserAdded do
    @moduledoc "Payload for a user message becoming visible in a session."
    @enforce_keys [:text]
    defstruct [:text, :content, :image_count]

    @type t :: %__MODULE__{
            text: String.t(),
            content: term(),
            image_count: non_neg_integer() | nil
          }
  end

  defmodule AssistantAdded do
    @moduledoc "Payload for a completed assistant message."
    defstruct [:text, :result, :error, :usage, :import_role]

    @type t :: %__MODULE__{
            text: String.t() | nil,
            result: term(),
            error: term(),
            usage: term(),
            import_role: String.t() | nil
          }
  end

  defmodule Cleared do
    @moduledoc "Payload for clearing visible session messages."
    defstruct []

    @type t :: %__MODULE__{}
  end

  @spec user_added(map() | keyword()) :: UserAdded.t()
  def user_added(attrs), do: attrs |> Map.new() |> then(&struct!(UserAdded, &1))

  @spec assistant_added(map() | keyword()) :: AssistantAdded.t()
  def assistant_added(attrs), do: attrs |> Map.new() |> then(&struct(AssistantAdded, &1))

  @spec cleared() :: Cleared.t()
  def cleared, do: %Cleared{}
end
