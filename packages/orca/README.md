# Orca

The package provides `orca-ide` for the desktop application and `orca` for the CLI.

## Linux runtime

The launchers supply the native libraries, icons, schemas, and external commands
used by Orca. The bundled CLI shim carries the same environment, including when
Orca installs a symlink to that shim in the user's home directory.

Computer use requires an active desktop session with D-Bus and AT-SPI access.
On NixOS, enable its session service:

```nix
services.gnome.at-spi2-core.enable = true;
```

Start a new desktop session after enabling the service so applications inherit
the updated accessibility settings.

The package sets the default `ORCA_COMPUTER_DESKTOP_SCRIPT_PROVIDER_PATH` to a
launcher for the bundled Linux provider, using a private Python environment with
PyGObject and the required typelibs. A user-supplied provider path takes precedence.
The private interpreter does not replace the user's preferred Python on `PATH`.
Local daemon processes inherit this provider setting; remote deployment payloads
retain their upstream hashes.

## Validation

The install check verifies the CLI version and Linux Python/typelib imports.
The macOS package checks Developer ID signatures for team `6CX3WHS9HZ` without
modifying the signed app bundle. The same signature check can run on Linux:

```sh
nix build .#checks.x86_64-linux.codesign-orca
```
