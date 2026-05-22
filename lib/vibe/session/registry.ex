defmodule Vibe.Session.Registry do
  @moduledoc false

  @spec via(String.t()) :: {:via, Registry, {Vibe.Registry, {:session, String.t()}}}
  def via(id), do: {:via, Registry, {Vibe.Registry, {:session, id}}}
end
