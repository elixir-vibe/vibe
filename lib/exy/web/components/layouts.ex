defmodule Exy.Web.Layouts do
  @moduledoc false

  use Exy.Web, :html

  embed_templates("layouts/*")
end
