defmodule Vibe.Web.Layouts do
  @moduledoc "Phoenix layout components for the web console."
  use Vibe.Web, :html

  embed_templates("layouts/*")
end
