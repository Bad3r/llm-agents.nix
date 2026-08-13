#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#nushell --command nu

# Generate the package-docs section of README.md.
# Metadata extraction lives in generate-package-docs.nix.

const BEGIN_MARKER = "<!-- BEGIN GENERATED PACKAGE DOCS -->"
const END_MARKER = "<!-- END GENERATED PACKAGE DOCS -->"

# Category display order.
const CATEGORY_ORDER = [
  "AI Coding Agents"
  "AI Assistants"
  "Claude Code Ecosystem"
  "ACP Ecosystem"
  "Usage Analytics"
  "Workflow & Project Management"
  "Code Review"
  "Voice & Transcription"
  "Memory & Code Intelligence"
  "Sandboxing & Isolation"
  "Skills & Plugins"
  "Utilities"
  "Uncategorized"
]

# All package metadata in one nix eval; drop nulls (filtered out or failed).
def all-packages-metadata [nix_file: string]: nothing -> table {
  let result = (^nix eval --json --file $nix_file | complete)
  if $result.exit_code != 0 {
    print -e $"Error running nix eval: exit ($result.exit_code)"
    if ($result.stderr | is-not-empty) {
      print -e $"stderr: ($result.stderr)"
    }
    exit 1
  }
  $result.stdout
  | from json
  | transpose package meta
  | where meta != null
  | sort-by package
}

# Render one package's <details> block.
def package-doc [package: string, meta: record]: nothing -> string {
  let description = ($meta.description? | default "No description available")
  let source = ($meta.sourceType? | default "unknown")
  let license = ($meta.license? | default "Check package")

  mut lines = [
    "<details>"
    $"<summary><strong>($package)</strong> - ($description)</summary>"
    ""
    $"- **Source**: ($source)"
    $"- **License**: ($license)"
  ]

  let homepage = ($meta.homepage? | default null)
  if $homepage != null and $homepage != "" {
    $lines = ($lines | append $"- **Homepage**: ($homepage)")
  }

  $lines = ($lines | append $"- **Usage**: `nix run github:numtide/llm-agents.nix#($package) -- --help`")
  # Escape the literal ( ) in the link target: in an interpolated string an
  # unescaped ( opens a subexpression.
  $lines = ($lines | append $"- **Nix**: [packages/($package)/package.nix]\(packages/($package)/package.nix\)")

  # Optional package-specific README (path relative to CWD).
  if ($"packages/($package)/README.md" | path exists) {
    $lines = ($lines | append $"- **Documentation**: See [packages/($package)/README.md]\(packages/($package)/README.md\) for detailed usage")
  }

  $lines = ($lines | append "")
  $lines = ($lines | append "</details>")
  $lines | str join "\n"
}

# Emit heading + package blocks + a trailing spacer for one category.
def category-block [category: string, rows: table]: nothing -> list<string> {
  mut out = [$"### ($category)\n"]
  for row in $rows {
    $out = ($out | append (package-doc $row.package $row.meta))
  }
  $out | append ""
}

# Build the whole generated section, grouped by category.
def generate-all-docs [nix_file: string]: nothing -> string {
  let data = (all-packages-metadata $nix_file)

  mut docs = []
  mut seen = []

  # Categories in the defined order.
  for category in $CATEGORY_ORDER {
    let rows = ($data | where {|r| ($r.meta.category? | default "Uncategorized") == $category })
    if ($rows | is-empty) { continue }
    $seen = ($seen | append $category)
    $docs = ($docs | append (category-block $category $rows))
  }

  # Any categories not in CATEGORY_ORDER, sorted.
  let leftover = (
    $data
    | get meta.category
    | uniq
    | sort
    | where {|c| $c not-in $seen }
  )
  for category in $leftover {
    let rows = ($data | where {|r| ($r.meta.category? | default "Uncategorized") == $category })
    $docs = ($docs | append (category-block $category $rows))
  }

  $docs | str join "\n" | str trim --right --char "\n"
}

# Splice the generated section between the markers in README.md.
# Returns the new content, or null if nothing changed.
def update-readme [readme_path: string, nix_file: string]: nothing -> any {
  let content = (open --raw $readme_path | decode utf-8)

  let begin_idx = ($content | str index-of $BEGIN_MARKER)
  let end_idx = ($content | str index-of $END_MARKER)

  if $begin_idx == -1 or $end_idx == -1 {
    print -e $"Error: Could not find markers in ($readme_path)"
    print -e $"  Expected: ($BEGIN_MARKER)"
    print -e $"  And: ($END_MARKER)"
    exit 1
  }
  if $end_idx < $begin_idx {
    print -e "Error: END marker appears before BEGIN marker"
    exit 1
  }

  let generated = (generate-all-docs $nix_file)

  # Split on the literal markers rather than slice by index, so the result
  # does not depend on how string indices count code points.
  let before = ($content | split row $BEGIN_MARKER | first)
  let after = ($content | split row $END_MARKER | last)
  let new_content = $"($before)($BEGIN_MARKER)\n\n($generated)\n($END_MARKER)($after)"

  if $new_content == $content { null } else { $new_content }
}

def main [] {
  let script_dir = $env.FILE_PWD
  let nix_file = ($script_dir | path join "generate-package-docs.nix")
  let readme_path = ($script_dir | path dirname | path join "README.md")

  if not ($readme_path | path exists) {
    print -e $"Error: README.md not found at ($readme_path)"
    exit 1
  }

  let updated = (update-readme $readme_path $nix_file)
  if $updated == null {
    print $"No changes to ($readme_path)"
  } else {
    $updated | save --force $readme_path
    print $"Updated ($readme_path)"
  }
}
