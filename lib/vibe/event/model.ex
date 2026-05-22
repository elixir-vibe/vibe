defmodule Vibe.Event.Model do
  @moduledoc "Typed semantic model-selection event payloads."

  defmodule Selected do
    @moduledoc "Payload for selecting a model."
    @enforce_keys [:model]
    defstruct [:model]
  end

  defmodule EffortSelected do
    @moduledoc "Payload for selecting model reasoning effort."
    @enforce_keys [:effort]
    defstruct [:effort]
  end

  defmodule UsageUpdated do
    @moduledoc "Payload for usage accounting updates."
    defstruct [:model, :input_tokens, :output_tokens, :total_tokens, :total_cost, :cost]
  end

  def selected(model) when is_binary(model), do: %Selected{model: model}
  def effort_selected(effort), do: %EffortSelected{effort: effort}
  def usage_updated(usage) when is_map(usage), do: struct(UsageUpdated, usage)
end
