Mix.Task.run("app.start")

{:ok, _credentials} = Vibe.Auth.Codex.ensure_fresh()

path = Path.expand(System.argv() |> List.first() || "test/fixtures/images/vision-smoke.png")
content = File.read!(path)
mime_type = Vibe.Image.mime_type(path) || "image/png"
{width, height} = Vibe.Image.dimensions(content, mime_type)

prompt = [
  Vibe.Model.Content.text(
    "Look at the attached labeled quadrant image. Answer exactly: WIDTHxHEIGHT UPPER_LEFT_LABEL LOWER_RIGHT_LABEL."
  ),
  Vibe.Model.Content.image(
    data: Base.encode64(content),
    mime_type: mime_type,
    filename: Path.basename(path),
    width: width,
    height: height
  )
]

session_id = "manual-image-smoke-#{System.unique_integer([:positive])}"

case Vibe.Model.Direct.ask(prompt,
       model: System.get_env("VIBE_IMAGE_SMOKE_MODEL") || "openai_codex:gpt-5.5",
       session_id: session_id,
       receive_timeout: 60_000
     ) do
  {:ok, response} ->
    IO.puts("session_id=#{session_id}")
    IO.puts(ReqLLM.Response.text(response) || inspect(response))

  {:error, reason} ->
    IO.puts(:stderr, inspect(reason))
    System.halt(1)
end
