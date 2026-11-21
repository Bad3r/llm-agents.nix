# shellcheck shell=bash
# Prepends Mesa's GBM backends to LD_PRELOAD; sourced by Linux wrappers of
# bundled Chromium and Electron builds. The GPU process's seccomp broker denies
# /run/opengl-driver, so libgbm's lazy dlopen of its backend fails with EACCES
# unless the backend is already mapped. glibc reuses a preloaded object only
# when the dlopen path matches it byte for byte, so the paths below are built
# exactly as Mesa's loader builds them.

gbmPreload() {
  local preload='' dir lib name
  local -a dirs
  local -A seen=()
  # Mesa searches nothing when the variable is set but empty.
  IFS=: read -ra dirs <<<"${GBM_BACKENDS_PATH-/run/opengl-driver/lib/gbm}"
  for dir in "${dirs[@]}"; do
    for lib in "$dir"/*_gbm.so; do
      name=${lib##*/}
      [[ -e $lib && -z ${seen[$name]-} ]] || continue
      seen[$name]=1
      # A preload whose dependencies do not resolve aborts exec; skip it.
      LD_PRELOAD=$lib "$BASH" -c : 2>/dev/null || continue
      preload+=${preload:+:}$lib
    done
  done
  if [[ -n $preload ]]; then
    export LD_PRELOAD=$preload${LD_PRELOAD:+:$LD_PRELOAD}
  fi
}

gbmPreload
unset -f gbmPreload
