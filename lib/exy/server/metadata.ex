defmodule Exy.Server.Metadata do
  @moduledoc false

  @path Path.expand("~/.exy/server.json")

  @spec path() :: Path.t()
  def path, do: @path

  @spec write!(map()) :: :ok
  def write!(metadata) do
    File.mkdir_p!(Path.dirname(@path))
    File.write!(@path, Jason.encode!(metadata, pretty: true))
  end

  @spec read() :: {:ok, map()} | {:error, term()}
  def read do
    with {:ok, text} <- File.read(@path), do: Jason.decode(text)
  end

  @spec delete() :: :ok
  def delete do
    File.rm(@path)
    :ok
  end
end
