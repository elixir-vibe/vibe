Mix.Task.run("app.start")

unless System.get_env("EXY_REAL_MODEL") in ["1", "true", "yes"] do
  IO.puts(:stderr, "Set EXY_REAL_MODEL=1 to run the real agent image smoke test.")
  System.halt(2)
end

{:ok, _credentials} = Exy.Auth.Codex.ensure_fresh()

path = Path.expand(System.argv() |> List.first() || "test/fixtures/images/vision-smoke.png")
content = File.read!(path)
mime_type = Exy.Image.mime_type(path) || "image/png"
{width, height} = Exy.Image.dimensions(content, mime_type)

prompt = [
  Exy.Model.Content.text(
    "Look at the attached labeled quadrant image. Answer exactly: WIDTHxHEIGHT UPPER_LEFT_LABEL LOWER_RIGHT_LABEL."
  ),
  Exy.Model.Content.image(
    data: Base.encode64(content),
    mime_type: mime_type,
    filename: Path.basename(path),
    width: width,
    height: height
  )
]

session_id = "agent-image-smoke-#{System.unique_integer([:positive])}"
parent = self()

{:ok, session} =
  Exy.Session.start_link(
    session_id: session_id,
    model: System.get_env("EXY_IMAGE_SMOKE_MODEL") || "openai_codex:gpt-5.5",
    streaming?: false
  )

:ok = Exy.Session.subscribe(session, parent)
:ok = Exy.Session.dispatch(session, {:submit_prompt, %{content: prompt}})

receive do
  {Exy.Session, :event, %{type: :assistant_message_added, data: data}} ->
    text =
      cond do
        is_binary(data[:text]) -> data[:text]
        is_binary(data[:error]) -> data[:error]
        match?(%{result: %{output: output}} when is_binary(output), data) -> data.result.output
        true -> inspect(data, pretty: true)
      end

    IO.puts("session_id=#{session_id}")
    IO.puts(text)

    normalized = String.downcase(text)

    unless String.contains?(normalized, "320x200") and
             String.contains?(normalized, "red") and
             String.contains?(normalized, "yellow") do
      IO.puts(:stderr, "Unexpected smoke response; expected 320x200 plus red and yellow labels.")
      System.halt(1)
    end

    :ok
after
  120_000 ->
    IO.puts(:stderr, "Timed out waiting for agent image smoke response.")
    System.halt(1)
end
