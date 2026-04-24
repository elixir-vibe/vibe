defmodule Exy.Terminal do
  @moduledoc """
  Supervised terminal pane helpers.
  """

  @spec start_pane(keyword()) :: DynamicSupervisor.on_start_child()
  def start_pane(opts \\ []) do
    DynamicSupervisor.start_child(Exy.Terminal.Supervisor, {Exy.Terminal.Pane, opts})
  end
end
