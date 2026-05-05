# Image support follow-up

- ReAct image tool results are bridged through `Exy.Agent.ImageRequestTransformer`, which injects image content from tool outputs as follow-up user content so OpenAI Responses sees `input_image` blocks. Interactive TUI/Web prompts now pass inline image references as semantic content and inject those images into ReAct model requests through the request transformer. Direct multimodal smoke is available via `mix run scripts/image_model_smoke.exs`; add a full real-model agent-loop smoke for interactive image prompts.
- Verify resize quality and compatibility against real `sips`/`magick`/`vips` installations and tune backend ordering if needed.
- Large images are copied to session/artifact directories through `Exy.Files.Artifacts`, exposed in Web through artifact URLs, and pruned with `exy sessions prune --artifacts`.
- Add clipboard image paste support by saving the clipboard image to a session artifact/temp file and inserting a normal file reference.
- TUI storybook and row-accounting fixtures cover image tool output fallback/Kitty behavior. Add a composer/user-message story for semantic prompt attachment badges if the visual design changes.
