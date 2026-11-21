# shellcheck shell=bash
# Chromium --zygote-cmd-prefix for Linux wrappers of bundled Chromium and
# Electron builds. The GPU process forks from the unsandboxed zygote, and its
# seccomp broker denies /run/opengl-driver, so libgbm's lazy dlopen of its
# backend fails with EACCES.
# glibc reuses a preloaded object only when the dlopen path matches it byte for
# byte, so the paths below are built exactly as Mesa's loader builds them.

for arg; do
  [[ $arg == --no-zygote-sandbox ]] || continue
  preload=
  declare -A seen=()
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
  [[ -n $preload ]] && export LD_PRELOAD=$preload${LD_PRELOAD:+:$LD_PRELOAD}
  break
done

exec "$@"
