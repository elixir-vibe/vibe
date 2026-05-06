defmodule Vibe.Storage.Search.Result do
  @moduledoc "Typed FTS search result with ranking and snippets."
  @type source :: :session | :memory

  @type t :: %__MODULE__{
          source: source(),
          id: String.t(),
          owner_id: String.t() | nil,
          title: String.t() | nil,
          text: String.t(),
          snippet: String.t() | nil,
          rank: number() | nil,
          at: DateTime.t() | nil,
          metadata: map()
        }

  defstruct [:source, :id, :owner_id, :title, :text, :snippet, :rank, :at, metadata: %{}]
end
