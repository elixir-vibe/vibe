defmodule Exy.Web.Components do
  @moduledoc "Imports shared component modules for Exy Web."

  defmacro __using__(_opts) do
    quote do
      import Exy.Web.Components.API
      import Exy.Web.Components.Core
      import Exy.Web.Components.Message
      import Exy.Web.Components.Shell
      import Exy.Web.Components.Tool
      import Exy.Web.Session.Components
      import Exy.Web.Sessions.Components
    end
  end
end
