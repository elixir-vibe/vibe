defmodule Exy.Storage.Importer do
  @moduledoc false

  @callback source() :: atom()
  @callback import_path(String.t()) :: {:ok, map()} | {:error, term()}
end
