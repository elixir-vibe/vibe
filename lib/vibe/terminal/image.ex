defmodule Vibe.Terminal.Image do
  @moduledoc "Terminal image protocol helpers for TUI renderers."

  alias Vibe.Model.Content

  defmodule Capabilities do
    @moduledoc false
    defstruct [:images, true_color?: false, hyperlinks?: false]
  end

  @type protocol :: :kitty | :iterm2 | nil
  @type capabilities :: %Capabilities{
          images: protocol(),
          true_color?: boolean(),
          hyperlinks?: boolean()
        }

  @default_cell_width_px 9
  @default_cell_height_px 18
  @chunk_size 4096

  @spec capabilities(map()) :: capabilities()
  def capabilities(env \\ System.get_env()) when is_map(env) do
    term_program = env |> Map.get("TERM_PROGRAM", "") |> String.downcase()
    term = env |> Map.get("TERM", "") |> String.downcase()
    color_term = env |> Map.get("COLORTERM", "") |> String.downcase()
    true_color? = color_term in ["truecolor", "24bit"]

    cond do
      Map.has_key?(env, "TMUX") or String.starts_with?(term, "tmux") or
          String.starts_with?(term, "screen") ->
        %Capabilities{images: nil, true_color?: true_color?, hyperlinks?: false}

      Map.has_key?(env, "KITTY_WINDOW_ID") or term_program == "kitty" ->
        %Capabilities{images: :kitty, true_color?: true, hyperlinks?: true}

      term_program == "ghostty" or String.contains?(term, "ghostty") or
          Map.has_key?(env, "GHOSTTY_RESOURCES_DIR") ->
        %Capabilities{images: :kitty, true_color?: true, hyperlinks?: true}

      Map.has_key?(env, "WEZTERM_PANE") or term_program == "wezterm" ->
        %Capabilities{images: :kitty, true_color?: true, hyperlinks?: true}

      Map.has_key?(env, "ITERM_SESSION_ID") or term_program == "iterm.app" ->
        %Capabilities{images: :iterm2, true_color?: true, hyperlinks?: true}

      term_program in ["vscode", "alacritty"] ->
        %Capabilities{images: nil, true_color?: true, hyperlinks?: true}

      true ->
        %Capabilities{images: nil, true_color?: true_color?, hyperlinks?: false}
    end
  end

  @spec image_line?(String.t()) :: boolean()
  def image_line?(line) when is_binary(line),
    do: String.contains?(line, ["\e_G", "\e]1337;File="])

  @spec kitty(String.t(), keyword()) :: IO.chardata()
  def kitty(base64, opts \\ []) when is_binary(base64) do
    params =
      ["a=T", "f=100", "q=2"]
      |> maybe_param("c", Keyword.get(opts, :columns))
      |> maybe_param("r", Keyword.get(opts, :rows))
      |> maybe_param("i", Keyword.get(opts, :image_id))

    if byte_size(base64) <= @chunk_size do
      ["\e_G", Enum.join(params, ","), ";", base64, "\e\\"]
    else
      chunks = chunks(base64)
      last_index = length(chunks) - 1

      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        cond do
          index == 0 -> ["\e_G", Enum.join(["m=1" | params], ","), ";", chunk, "\e\\"]
          index == last_index -> ["\e_Gm=0;", chunk, "\e\\"]
          true -> ["\e_Gm=1;", chunk, "\e\\"]
        end
      end)
    end
  end

  @spec iterm2(String.t(), keyword()) :: IO.chardata()
  def iterm2(base64, opts \\ []) when is_binary(base64) do
    params =
      ["inline=1"]
      |> maybe_iterm_param("width", Keyword.get(opts, :width))
      |> maybe_iterm_param("height", Keyword.get(opts, :height))
      |> maybe_iterm_param("name", encoded_name(Keyword.get(opts, :name)))

    ["\e]1337;File=", Enum.join(params, ";"), ":", base64, "\a"]
  end

  @spec rows(pos_integer() | nil, pos_integer() | nil, pos_integer(), keyword()) :: pos_integer()
  def rows(width_px, height_px, target_width_cells, opts \\ [])

  def rows(width_px, height_px, target_width_cells, opts)
      when is_integer(width_px) and is_integer(height_px) and width_px > 0 and height_px > 0 do
    cell_width = Keyword.get(opts, :cell_width_px, @default_cell_width_px)
    cell_height = Keyword.get(opts, :cell_height_px, @default_cell_height_px)
    target_width_px = max(target_width_cells, 1) * cell_width
    scaled_height_px = height_px * target_width_px / width_px
    max(ceil(scaled_height_px / cell_height), 1)
  end

  def rows(_width_px, _height_px, _target_width_cells, _opts), do: 4

  @spec fallback(Content.Image.t()) :: String.t()
  def fallback(%Content.Image{} = image) do
    parts =
      [image.filename, image.mime_type, dimensions_text(image)]
      |> Enum.reject(&(&1 in [nil, ""]))

    "[Image: #{Enum.join(parts, " ")}]"
  end

  defp chunks(base64), do: do_chunks(base64, [])
  defp do_chunks(<<>>, acc), do: Enum.reverse(acc)

  defp do_chunks(<<chunk::binary-size(@chunk_size), rest::binary>>, acc),
    do: do_chunks(rest, [chunk | acc])

  defp do_chunks(rest, acc), do: Enum.reverse([rest | acc])

  defp maybe_param(params, _name, nil), do: params
  defp maybe_param(params, name, value), do: Enum.concat(params, ["#{name}=#{value}"])

  defp maybe_iterm_param(params, _name, nil), do: params
  defp maybe_iterm_param(params, name, value), do: Enum.concat(params, ["#{name}=#{value}"])

  defp encoded_name(nil), do: nil
  defp encoded_name(name), do: Base.encode64(to_string(name))

  defp dimensions_text(%{width: width, height: height})
       when is_integer(width) and is_integer(height),
       do: "#{width}x#{height}"

  defp dimensions_text(_image), do: nil
end
