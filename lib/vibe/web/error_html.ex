defmodule Vibe.Web.ErrorHTML do
  @moduledoc "Error page renderer for the web console."
  use Vibe.Web, :html

  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)
end
