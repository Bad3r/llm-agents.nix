{ writeShellScript }:
writeShellScript "zygote-gbm-preload" (
  builtins.replaceStrings [ "@gbmPreload@" ] [ "${./gbm-preload.sh}" ] (
    builtins.readFile ./zygote-gbm-preload.sh
  )
)
