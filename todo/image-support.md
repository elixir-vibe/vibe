# Image support follow-up

- ReAct tool results currently expose image content parts through `ReadResult.__content_parts__`, and Jido turn formatting preserves them as `image_url` parts. Verify each ReqLLM provider actually projects image tool results into the next request; OpenAI Responses function-call outputs may accept only text output, so full pixel feedback after a tool call may need request transformation that injects image parts as a follow-up user content item.
- Add `Exy.Image.Resize` with supervised command backends (`sips`, `magick`, possibly `vips`) and enforce model-safe limits around 2000×2000 and ~4.5MB base64 payloads.
- Add an artifact storage policy for large images: inline small images in session storage, copy large images under the session artifacts directory and store an image reference.
- Add clipboard image paste support by saving the clipboard image to a session artifact/temp file and inserting a normal file reference.
- Add TUI storybook/snapshot fixtures for image fallback and Kitty protocol row accounting.
