# shellcheck shell=bash
# Setup hook that removes the `rust-version` (MSRV) field from Cargo manifests.
# This prevents "package requires rustc X.Y" errors when upstream pins an MSRV
# newer than the rustc currently shipped by nixpkgs, even though the crate
# still compiles fine on the older toolchain.
#
# Both plain `rust-version = "..."` declarations and the workspace-inherited
# form `rust-version.workspace = true` (or `rust-version = { workspace = true }`)
# are stripped, so removing the workspace.package definition cannot break
# member crates that inherit it.

unpinCargoMsrv() {
  local manifests
  mapfile -t manifests < <(find . -name Cargo.toml)
  if [[ ${#manifests[@]} -eq 0 ]]; then
    return
  fi

  echo "unpinCargoMsrvHook: removing rust-version from ${#manifests[@]} Cargo.toml file(s)"
  sed -i -E '/^[[:space:]]*rust-version([[:space:]]*=|\.workspace[[:space:]]*=)/d' "${manifests[@]}"
}

postPatchHooks+=(unpinCargoMsrv)
