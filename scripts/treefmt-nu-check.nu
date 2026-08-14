# treefmt hook: check that each .nu file parses.
# Uses a `for` loop because nu-check misreports errors inside `each`.
def main [...files: string] {
  for f in $files {
    # nu-check resolves relative paths against $env.FILE_PWD (this script's
    # store dir), so make them absolute against the CWD.
    let target = ($f | path expand --no-symlink)
    # --debug raises on parse errors with a rendered diagnostic
    try {
      nu-check --debug $target | ignore
    } catch {|e|
      print -e $"nu-check: parse error in ($f)"
      print -e ($e.rendered? | default ($e.msg? | default "parse error"))
      exit 1
    }
  }
}
