defmodule Vibe.Web.Components do
  @moduledoc "Imports shared component modules for Vibe Web."

  defmacro __using__(_opts) do
    quote do
      import PhoenixIconify, only: [icon: 1]
      import Vibe.Web.Components.API
      import Vibe.Web.Components.Core
      import Vibe.Web.Components.Message
      import Vibe.Web.Components.Shell
      import Vibe.Web.Presentation.Tool
      import Vibe.Web.Plugins.Components
      import Vibe.Web.Session.Components
      import Vibe.Web.Sessions.Components
    end
  end
end
