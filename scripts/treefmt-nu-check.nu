# treefmt hook: check that each .nu file parses. No autoformat — nufmt is alpha.
# nu-check runs per file in a `for` loop; it misreports errors inside `each`.
def main [...files: string] {
  for f in $files {
    # nu-check resolves a relative path against $env.FILE_PWD (this wrapper's
    # store dir), so make it absolute against the CWD.
    let target = ($f | path expand --no-symlink)
    # --debug raises on a parse error with a rendered diagnostic; report the
    # file and stop at the first failure.
    try {
      nu-check --debug $target | ignore
    } catch {|e|
      print -e $"nu-check: parse error in ($f)"
      print -e ($e.rendered? | default ($e.msg? | default "parse error"))
      exit 1
    }
  }
}
