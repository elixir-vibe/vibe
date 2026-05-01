defmodule Exy.Web.Layouts do
  @moduledoc "Internal implementation module."
  use Exy.Web, :html

  embed_templates("layouts/*")
end
