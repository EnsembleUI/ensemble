#!/usr/bin/env bash
set -euo pipefail

# melos already committed and tagged the versioned/dependent packages.
# Repair its dependency-constraint rewrite (fix_melos_version_rewrite.dart),
# fold it into that same commit, and re-point whatever tags melos created --
# rather than hardcode which packages get tagged. Shared by both release
# workflows so they can't drift apart.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tags="$(git tag --points-at HEAD)"

dart pub get
dart run "$script_dir/fix_melos_version_rewrite.dart"

git add -u
git commit --amend --no-edit

while IFS= read -r tag; do
  [ -n "$tag" ] && git tag -f "$tag" HEAD
done <<< "$tags"
