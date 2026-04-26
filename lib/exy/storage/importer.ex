defmodule Exy.Storage.Importer do
  @moduledoc false

  @callback source() :: atom()
  @callback import_path(String.t()) :: {:ok, map()} | {:error, term()}
  @callback import_path(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @optional_callbacks import_path: 2
end
