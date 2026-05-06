defmodule Vibe.Terminal do
  @moduledoc """
  Supervised terminal pane helpers.
  """

  @spec start_pane(keyword()) :: DynamicSupervisor.on_start_child()
  def start_pane(opts \\ []) do
    DynamicSupervisor.start_child(Vibe.Terminal.Supervisor, {Vibe.Terminal.Pane, opts})
  end
end
