#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#nushell --command nu

# Generate the package-docs section of README.md.
# Metadata extraction lives in generate-package-docs.nix.

const BEGIN_MARKER = "<!-- BEGIN GENERATED PACKAGE DOCS -->"
const END_MARKER = "<!-- END GENERATED PACKAGE DOCS -->"

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

# Drop nulls: packages that were filtered out or failed to evaluate.
def all-packages-metadata [nix_file: string]: nothing -> table {
  ^nix eval --json --file $nix_file
  | from json
  | transpose package meta
  | where meta != null
  | sort-by package
}

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
  # \( because an unescaped ( in an interpolated string opens a subexpression
  $lines = ($lines | append $"- **Nix**: [packages/($package)/package.nix]\(packages/($package)/package.nix\)")

  if ($"packages/($package)/README.md" | path exists) {
    $lines = ($lines | append $"- **Documentation**: See [packages/($package)/README.md]\(packages/($package)/README.md\) for detailed usage")
  }

  $lines = ($lines | append "")
  $lines = ($lines | append "</details>")
  $lines | str join "\n"
}

def category-block [category: string, rows: table]: nothing -> list<string> {
  [$"### ($category)\n"]
  | append ($rows | each {|r| package-doc $r.package $r.meta })
  | append ""
}

# Categories in CATEGORY_ORDER first, then any remaining ones sorted.
def generate-all-docs [nix_file: string]: nothing -> string {
  let by_category = (
    all-packages-metadata $nix_file
    | group-by {|r| $r.meta.category? | default "Uncategorized" }
  )
  let present = ($by_category | columns)
  ($CATEGORY_ORDER | where {|c| $c in $present })
  | append ($present | where {|c| $c not-in $CATEGORY_ORDER } | sort)
  | each {|c| category-block $c ($by_category | get $c) }
  | flatten
  | str join "\n"
  | str trim --right --char "\n"
}

# Returns the new README content, or null if nothing changed.
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

  # Split on the markers instead of slicing by index: str index-of counts
  # code points, not bytes.
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
