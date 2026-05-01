defmodule Exy.WebTools.FetchResult do
  @moduledoc """
  Normalized result for a URL fetch request.
  """

  @type format :: :markdown | :text | :html | :json | :pdf_text

  @type t :: %__MODULE__{
          url: String.t(),
          final_url: String.t() | nil,
          provider: atom(),
          status: pos_integer() | nil,
          content_type: String.t() | nil,
          format: format(),
          text: String.t(),
          size_bytes: non_neg_integer(),
          total_chars: non_neg_integer(),
          truncated?: boolean(),
          redirected?: boolean(),
          selector: String.t() | nil,
          metadata: map()
        }

  defstruct url: "",
            final_url: nil,
            provider: nil,
            status: nil,
            content_type: nil,
            format: :markdown,
            text: "",
            size_bytes: 0,
            total_chars: 0,
            truncated?: false,
            redirected?: false,
            selector: nil,
            metadata: %{}
end
