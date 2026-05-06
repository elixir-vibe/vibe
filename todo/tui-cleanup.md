# TUI cleanup TODO

- Hide or relocate developer-only trace/testing artifacts so end users do not see root-level temporary files such as escripts, tarballs, crash dumps, trace directories, or disposable scenario outputs during normal Vibe use.
- Add a documented cleanup command or developer script for removing generated local test artifacts after real PTY/TUI dogfood runs.
- Keep trace capture opt-in and clearly labeled as debug/dev tooling in CLI help and docs.
