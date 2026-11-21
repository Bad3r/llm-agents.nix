# shellcheck shell=bash
# Chromium --zygote-cmd-prefix that applies the GBM preload to the unsandboxed
# zygote only, which forks the GPU process, so renderers map no Mesa code.
# Electron builds abort on any *-cmd-prefix switch and source gbm-preload.sh
# from their wrapper instead.

for arg; do
  [[ $arg == --no-zygote-sandbox ]] || continue
  # shellcheck source=/dev/null
  . @gbmPreload@
  break
done

exec "$@"
