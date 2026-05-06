# Image support follow-up

- ReAct image tool results are bridged through `Vibe.Agent.ImageRequestTransformer`, which injects image content from tool outputs as follow-up user content so OpenAI Responses sees `input_image` blocks. Interactive TUI/Web prompts now pass inline image references as semantic content and inject those images into ReAct model requests through the request transformer. Direct multimodal smoke is available via `mix run scripts/image_model_smoke.exs`; full agent-loop smoke is available via `VIBE_REAL_MODEL=1 mix run scripts/image_agent_smoke.exs`.
- Verify resize quality and compatibility against real `sips`/`magick`/`vips` installations and tune backend ordering if needed.
- Large images are copied to session/artifact directories through `Vibe.Files.Artifacts`, exposed in Web through artifact URLs, and pruned with `vibe sessions prune --artifacts`.
- Clipboard image paste uses Pi-style composer insertion in the TUI: `Ctrl+V` reads the clipboard PNG via `pngpaste`, stores it under session artifacts, and inserts an `@path` marker for the existing semantic attachment submit path. Add browser paste-event support later.
- TUI storybook and row-accounting fixtures cover image tool output fallback/Kitty behavior. Add a composer/user-message story for semantic prompt attachment badges if the visual design changes.
