# OTP Rules

Rules for testing GenServers, Supervisors, and OTP processes correctly.

OTP processes are the backbone of Elixir concurrency, but they introduce
unique testing challenges: asynchronous messages, process state, registration
conflicts, time-based behaviour, and supervision trees. These rules encode
the patterns that keep OTP tests fast, deterministic, and maintainable.

## Rules

| ID | Slug | Severity | Summary |
|----|------|----------|---------|
| ETC-OTP-001 | [test-pure-module-directly](test-pure-module-directly/RULE.md) | recommendation | Test the pure module, not the GenServer wrapper |
| ETC-OTP-002 | [genserver-public-api-only](genserver-public-api-only/RULE.md) | warning | Prefer testing GenServers through their public API |
| ETC-OTP-003 | [force-sync-after-cast](force-sync-after-cast/RULE.md) | warning | Force synchronization after GenServer.cast |
| ETC-OTP-004 | [unique-process-names](unique-process-names/RULE.md) | warning | Use unique names for per-test processes |
| ETC-OTP-005 | [test-supervision-restart](test-supervision-restart/RULE.md) | recommendation | Test supervision restart with real supervisors |
| ETC-OTP-006 | [control-time-based-processes](control-time-based-processes/RULE.md) | recommendation | Inject controllable time for periodic processes |

## Key Principles

- **Purity Separation** — Keep business logic in pure modules; GenServers are thin wrappers.
- **Thin Processes** — Processes manage state and concurrency, not computation.
- **Public Interface** — Test the public API, not `:sys.get_state/1` internals.
- **Assert, Don't Sleep** — Use synchronous calls to drain mailboxes, never `Process.sleep`.
- **Async Default** — Unique process names allow async tests to run safely in parallel.
- **Integration Required** — Test supervision with real `Supervisor` instances.
