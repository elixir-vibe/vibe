defmodule Vibe.Plugin.Context do
  @moduledoc """
  Context passed to plugins and plugin workers.
  """

  @type t :: %{
          optional(:session_id) => String.t(),
          optional(:cwd) => String.t(),
          optional(:model) => String.t(),
          optional(:ui) => module(),
          optional(:bus) => module()
        }

  @spec from_opts(keyword() | map()) :: t()
  def from_opts(opts) when is_list(opts), do: opts |> Map.new() |> from_opts()

  def from_opts(opts) when is_map(opts) do
    opts
    |> Map.take([:session_id, :cwd, :model])
    |> Map.put_new(:cwd, File.cwd!())
    |> Map.put(:ui, Vibe.Plugin.UI)
    |> Map.put(:bus, Vibe.Event.Bus)
  end
end
