defmodule Exy.Web.Layouts do
  @moduledoc "Phoenix layout components for the web console."
  use Exy.Web, :html

  embed_templates("layouts/*")
end
