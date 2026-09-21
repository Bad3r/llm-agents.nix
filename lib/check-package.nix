# Wraps a package as its pkgs-<name> check: only FHS-like directories may sit
# directly under $out, anything else collides in buildEnv profiles (#9364).
{ pkgs }:
name: pkg:
pkgs.runCommand "check-${name}" { } ''
  for f in ${pkg}/* ${pkg}/.[!.]*; do
    case "$(basename "$f")" in
      bin|sbin|lib|lib64|libexec|share|include|etc|opt|Applications|nix-support|'*'|'.[!.]*') ;;
      *) echo "${name}: $f is not FHS-like (see AGENTS.md, Output Layout)"; exit 1 ;;
    esac
  done
  ln -s ${pkg} $out
''
