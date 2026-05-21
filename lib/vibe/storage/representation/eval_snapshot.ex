defmodule Vibe.Storage.Representation.EvalSnapshot do
  @moduledoc "Storage representation for session eval state snapshots."

  @type t :: %{binding: Code.binding(), env: Macro.Env.t()}

  @spec encode(Code.binding(), Macro.Env.t()) :: binary()
  def encode(binding, %Macro.Env{} = env) when is_list(binding) do
    :erlang.term_to_binary(%{binding: binding, env: env})
  end

  @spec decode(binary()) :: {:ok, t()} | :error
  def decode(binary) when is_binary(binary) do
    with decoded when is_binary(decoded) <- maybe_base64_decode(binary),
         %{binding: binding, env: %Macro.Env{} = env} <- :erlang.binary_to_term(decoded, [:safe]) do
      {:ok, %{binding: binding, env: env}}
    else
      _ -> :error
    end
  rescue
    _exception -> :error
  end

  @spec entry(String.t(), Code.binding(), Macro.Env.t()) :: {:ok, map()} | {:error, term()}
  def entry(session_id, binding, %Macro.Env{} = env)
      when is_binary(session_id) and is_list(binding) do
    {:ok,
     %{
       "entry_type" => "eval_state",
       "session_id" => session_id,
       "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
       "state" => binding |> encode(env) |> Base.encode64()
     }}
  rescue
    exception -> {:error, exception}
  end

  @spec decode_line(String.t(), term()) :: t() | term()
  def decode_line(line, acc) do
    with {:ok, %{"entry_type" => "eval_state", "state" => encoded}} <- Jason.decode(line),
         {:ok, state} <- decode(encoded) do
      state
    else
      _ -> acc
    end
  end

  defp maybe_base64_decode(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, binary} -> binary
      :error -> encoded
    end
  end
end
