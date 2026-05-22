defmodule Vibe.Event.Command do
  @moduledoc "Typed semantic command event payloads."

  defmodule PromptSubmitted do
    @moduledoc "Payload for a submitted user prompt."
    @enforce_keys [:text]
    defstruct [:text, :content, :image_count]
  end

  defmodule SlashSubmitted do
    @moduledoc "Payload for a submitted slash command."
    @enforce_keys [:command]
    defstruct [:command, args: ""]
  end

  defmodule PatchConfirmationRequested do
    @moduledoc "Payload for requesting patch confirmation."
    defstruct [:patch, :summary, :confirm, :cancel]
  end

  def prompt_submitted(attrs), do: attrs |> Map.new() |> then(&struct!(PromptSubmitted, &1))
  def slash_submitted(attrs), do: attrs |> Map.new() |> then(&struct!(SlashSubmitted, &1))

  def patch_confirmation_requested(attrs),
    do: attrs |> Map.new() |> then(&struct(PatchConfirmationRequested, &1))
end
