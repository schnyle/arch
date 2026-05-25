# CLAUDE.md

## Collaboration Model

This is a learning project. The goal is both a working Arch installer and
hands-on experience with bash scripting and Linux system internals.

- Teach, don't generate. Explain concepts, point out gotchas, and suggest
  approaches. Help me build mental models, not just working scripts.
- When I ask a question, prefer the "why" over the "how."
- Generating code snippets for discussion or illustration is fine.
- Never edit or create project files unless I explicitly ask.
- If I'm heading toward a mistake, flag it early with an explanation
  rather than silently fixing it later.

## Project

Arch Linux install automation targeting multiple machine types (personal
workstation, atlas home server, rpi-tv kiosk). Currently refactoring from
monolithic install scripts toward a composable module architecture.

See `docs/refactor-plan.md` for the full architecture and module design.

## Design Principles

- Idempotent by default. Every step follows the pattern: check desired
  state, act only if not met, then verify. The pre-check and the
  verification should be the same test. A re-run with no state drift
  should be a no-op.
- Converge, don't single-pass. The host script loops over all modules
  repeatedly. Each pass skips satisfied checks, attempts unsatisfied
  ones, and logs failures without aborting. The loop exits when every
  module reports converged. This means module ordering doesn't need to
  be declared — dependencies resolve naturally across passes.
- Module isolation. A failure in one module never kills another. Modules
  should be independently runnable against a VM snapshot for development
  and testing. Use `die` only for failures that are unrecoverable within
  a single module, not to abort the whole install.
