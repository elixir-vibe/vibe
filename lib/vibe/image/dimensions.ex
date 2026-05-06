defmodule Vibe.Image.Dimensions do
  @moduledoc "Pure Elixir image dimension parsers for supported inline image formats."

  @spec detect(binary(), String.t()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def detect(binary, "image/png"), do: png(binary)
  def detect(binary, "image/jpeg"), do: jpeg(binary)
  def detect(binary, "image/gif"), do: gif(binary)
  def detect(binary, "image/webp"), do: webp(binary)
  def detect(_binary, _mime_type), do: :error

  @spec png(binary()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def png(
        <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _len::32, "IHDR", width::32, height::32,
          _rest::binary>>
      )
      when width > 0 and height > 0,
      do: {:ok, {width, height}}

  def png(_binary), do: :error

  @spec gif(binary()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def gif(<<sig::binary-size(6), width::little-16, height::little-16, _rest::binary>>)
      when sig in ["GIF87a", "GIF89a"] and width > 0 and height > 0,
      do: {:ok, {width, height}}

  def gif(_binary), do: :error

  @spec jpeg(binary()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def jpeg(<<0xFF, 0xD8, rest::binary>>), do: jpeg_segments(rest)
  def jpeg(_binary), do: :error

  defp jpeg_segments(
         <<0xFF, marker, _length::16, _precision, height::16, width::16, _rest::binary>>
       )
       when marker in 0xC0..0xC2 and width > 0 and height > 0,
       do: {:ok, {width, height}}

  defp jpeg_segments(<<0xFF, marker, rest::binary>>) when marker in [0xD8, 0xD9] do
    jpeg_segments(rest)
  end

  defp jpeg_segments(<<0xFF, _marker, length::16, rest::binary>>) when length >= 2 do
    skip = length - 2

    case rest do
      <<_segment::binary-size(skip), tail::binary>> -> jpeg_segments(tail)
      _too_short -> :error
    end
  end

  defp jpeg_segments(<<_byte, rest::binary>>), do: jpeg_segments(rest)
  defp jpeg_segments(_binary), do: :error

  @spec webp(binary()) :: {:ok, {pos_integer(), pos_integer()}} | :error
  def webp(
        <<"RIFF", _size::little-32, "WEBP", "VP8 ", _chunk_size::little-32,
          _frame_tag::binary-size(3), 0x9D, 0x01, 0x2A, width_raw::little-16,
          height_raw::little-16, _rest::binary>>
      ) do
    width = Bitwise.band(width_raw, 0x3FFF)
    height = Bitwise.band(height_raw, 0x3FFF)
    positive_dimensions(width, height)
  end

  def webp(
        <<"RIFF", _size::little-32, "WEBP", "VP8L", _chunk_size::little-32, 0x2F, bits::little-32,
          _rest::binary>>
      ) do
    width = Bitwise.band(bits, 0x3FFF) + 1
    height = Bitwise.band(Bitwise.bsr(bits, 14), 0x3FFF) + 1
    positive_dimensions(width, height)
  end

  def webp(
        <<"RIFF", _size::little-32, "WEBP", "VP8X", _chunk_size::little-32, _flags,
          _reserved::binary-size(3), width_minus_one::little-24, height_minus_one::little-24,
          _rest::binary>>
      ) do
    positive_dimensions(width_minus_one + 1, height_minus_one + 1)
  end

  def webp(_binary), do: :error

  defp positive_dimensions(width, height) when width > 0 and height > 0,
    do: {:ok, {width, height}}

  defp positive_dimensions(_width, _height), do: :error
end
