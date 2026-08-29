# shellcheck shell=bash
# Sourced by the chatgpt wrapper on Linux. The app downloads a generic-linux
# "codex-primary-runtime" (python, node, git, libreoffice, ...) into
# ~/.cache/codex-runtimes and execs binaries from it. Rewrite their ELF
# interpreter/RPATH in place whenever the bundle changes so they run on NixOS.

chatgpt_patch_runtimes() {
  local root="$HOME/.cache/codex-runtimes" dir stamp want interp
  interp=$(<@dynamicLinker@)
  for dir in "$root"/*/; do
    [[ -f "$dir/runtime.json" ]] || continue
    # Re-patch when either the bundle or our toolchain (store paths) changed.
    want=$(
      cat "$dir/runtime.json"
      echo "$interp @libs@"
    )
    stamp="$dir/.nix-patched"
    [[ -f $stamp && "$(<"$stamp")" == "$want" ]] && continue
    echo "chatgpt: patching $dir for NixOS" >&2
    # libpython3.so carries a bogus $ORIGIN NEEDED entry. The bundled fallback
    # git wants Debian's libcurl-gnutls ABI; the app prefers git from PATH.
    # shellcheck disable=SC2016
    @autoFormatelf@ -j 0 \
      --interpreter "$interp" --libc @libc@ \
      --paths "$dir" --libs @libs@ \
      --ignore-missing '$ORIGIN/*' 'libcurl-gnutls.so.4' >&2 || continue
    printf '%s' "$want" >"$stamp"
  done
}

# The installer extracts into a staging dir and rename()s it into place, so a
# moved_to event on the parent is the signal that a new runtime has landed.
if [[ -n ${HOME:-} ]]; then
  mkdir -p "$HOME/.cache/codex-runtimes"
  chatgpt_patch_runtimes
  app_pid=$$
  (
    while kill -0 "$app_pid" 2>/dev/null; do
      @inotifywait@ -qq -t 60 -e moved_to "$HOME/.cache/codex-runtimes" || continue
      chatgpt_patch_runtimes
    done
  ) &
  unset app_pid
fi
