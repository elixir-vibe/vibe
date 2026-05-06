defmodule Vibe.Image.Resize.Backend do
  @moduledoc "Behaviour for image resize backends."

  @type resize_opts :: [
          max_width: pos_integer(),
          max_height: pos_integer(),
          max_bytes: pos_integer(),
          quality: pos_integer(),
          tmp_dir: Path.t()
        ]

  @callback available?() :: boolean()
  @callback supports?(Vibe.Image.t()) :: boolean()
  @callback resize(Vibe.Image.t(), resize_opts()) :: {:ok, Vibe.Image.t()} | {:error, term()}
end
