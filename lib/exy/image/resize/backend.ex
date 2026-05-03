defmodule Exy.Image.Resize.Backend do
  @moduledoc "Behaviour for image resize backends."

  @type resize_opts :: [
          max_width: pos_integer(),
          max_height: pos_integer(),
          max_bytes: pos_integer(),
          quality: pos_integer(),
          tmp_dir: Path.t()
        ]

  @callback available?() :: boolean()
  @callback supports?(Exy.Image.t()) :: boolean()
  @callback resize(Exy.Image.t(), resize_opts()) :: {:ok, Exy.Image.t()} | {:error, term()}
end
