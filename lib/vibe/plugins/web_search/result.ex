defmodule Vibe.Plugins.WebSearch.Result do
  @moduledoc "Typed web search result for plugin UI."
  @type t :: %__MODULE__{
          title: String.t(),
          url: String.t(),
          author: String.t() | nil,
          published_date: String.t() | nil,
          text: String.t(),
          highlights: [String.t()],
          summary: String.t() | nil
        }

  defstruct [:title, :url, :author, :published_date, :summary, text: "", highlights: []]
end
