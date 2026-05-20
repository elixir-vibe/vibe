# Remote SSH transport

- Add an OTP SSH daemon alongside the trusted Erlang distribution transport.
- Keep SSH user-facing and constrained: no default remote IEx/shell; expose a versioned Vibe protocol over an SSH subsystem/channel.
- Back operations with existing `Vibe.Session` and `Vibe.Subagents` APIs: list, start, attach, send input, stream UI events, resize, detach, cancel.
- Store SSH endpoints in `Vibe.Remote.KnownNodes` with `transport: "ssh"`, host key metadata, and user label.
- Keep `vibe connect --dist node@host` for trusted internal distribution; make plain remote host UX prefer SSH once the daemon/client protocol exists.
