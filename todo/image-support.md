# Image support follow-up

- ReAct image tool results are bridged through `Exy.Agent.ImageRequestTransformer`, which injects image content from tool outputs as follow-up user content so OpenAI Responses sees `input_image` blocks. Verify this with a real model call and extend provider-specific tests beyond OpenAI Responses if needed.
- Add `Exy.Image.Resize` with supervised command backends (`sips`, `magick`, possibly `vips`) and enforce model-safe limits around 2000×2000 and ~4.5MB base64 payloads.
- Add an artifact storage policy for large images: inline small images in session storage, copy large images under the session artifacts directory and store an image reference.
- Add clipboard image paste support by saving the clipboard image to a session artifact/temp file and inserting a normal file reference.
- Add TUI storybook/snapshot fixtures for image fallback and Kitty protocol row accounting.
