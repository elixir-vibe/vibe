defmodule Exy.Web.ErrorHTML do
  @moduledoc false

  use Exy.Web, :html

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
