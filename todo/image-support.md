# Image support follow-up

- ReAct image tool results are bridged through `Exy.Agent.ImageRequestTransformer`, which injects image content from tool outputs as follow-up user content so OpenAI Responses sees `input_image` blocks. Verify this with a real model call and extend provider-specific tests beyond OpenAI Responses if needed.
- Verify resize quality and compatibility against real `sips`/`magick`/`vips` installations and tune backend ordering if needed.
- Large images are now copied to session/artifact directories through `Exy.Files.Artifacts`; continue by exposing artifact URLs in Web and adding cleanup/prune behavior.
- Add clipboard image paste support by saving the clipboard image to a session artifact/temp file and inserting a normal file reference.
- Add TUI storybook/snapshot fixtures for image fallback and Kitty protocol row accounting.
