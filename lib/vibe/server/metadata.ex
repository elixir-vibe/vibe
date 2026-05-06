defmodule Vibe.Server.Metadata do
  @moduledoc "Server node metadata persistence for client discovery."
  @spec path() :: Path.t()
  def path, do: Vibe.Paths.server_metadata()

  @spec write!(map()) :: :ok
  def write!(metadata) do
    path = path()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(metadata, pretty: true))
  end

  @spec read() :: {:ok, map()} | {:error, term()}
  def read do
    with {:ok, text} <- File.read(path()), do: Jason.decode(text)
  end

  @spec delete() :: :ok
  def delete do
    File.rm(path())
    :ok
  end
end
