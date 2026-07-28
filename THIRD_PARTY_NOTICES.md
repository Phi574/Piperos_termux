# Third-party notices

## Termux

This project builds on source and build tooling from:

- `termux/termux-packages`: package definitions and build infrastructure.
- `termux/termux-app`: Android terminal and Termux integration references.

The `termux-app` repository is GPL-3.0-only except for documented
file/directory-level exceptions. Its `terminal-emulator` and `terminal-view`
modules include Android Terminal Emulator code under Apache License 2.0.
The `termux-shared` module contains MIT, GPL-3.0-only, Apache-2.0, and
GPL-2.0-with-Classpath-exception portions. Always preserve the upstream
license attached to each copied file.

Upstream sources:

- https://github.com/termux/termux-app
- https://github.com/termux/termux-packages
- https://github.com/termux/termux-exec

PiperOS modifications include custom application paths, release manifests,
runtime distribution logic, and Android integration. Corresponding source
for every distributed runtime must remain available from this repository.

