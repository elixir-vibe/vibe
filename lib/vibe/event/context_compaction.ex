defmodule Vibe.Event.ContextCompaction do
  @moduledoc "Typed semantic context-compaction event payloads."

  defmodule Started do
    @moduledoc "Payload for context compaction starting."
    @enforce_keys [:tokens_before]
    defstruct [:tokens_before]

    @type t :: %__MODULE__{tokens_before: non_neg_integer()}
  end

  defmodule Finished do
    @moduledoc "Payload for context compaction finishing."
    @enforce_keys [:summary]
    defstruct [:summary]

    @type t :: %__MODULE__{summary: String.t()}
  end

  defmodule Failed do
    @moduledoc "Payload for context compaction failing."
    @enforce_keys [:reason]
    defstruct [:reason]

    @type t :: %__MODULE__{reason: String.t()}
  end

  @spec started(non_neg_integer()) :: Started.t()
  def started(tokens_before) when is_integer(tokens_before) and tokens_before >= 0,
    do: %Started{tokens_before: tokens_before}

  @spec finished(String.t()) :: Finished.t()
  def finished(summary) when is_binary(summary), do: %Finished{summary: summary}

  @spec failed(String.t()) :: Failed.t()
  def failed(reason) when is_binary(reason), do: %Failed{reason: reason}
end
