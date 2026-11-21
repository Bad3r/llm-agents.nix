{ writeShellScript }:
writeShellScript "zygote-gbm-preload" (builtins.readFile ./zygote-gbm-preload.sh)
