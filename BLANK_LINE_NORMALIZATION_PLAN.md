# Blank Line Normalization Plan for `commonmarker-merge`

_Date: 2026-03-19_

## Role in the family refactor

`commonmarker-merge` is a thin Markdown-family wrapper repo for this effort.

Its job is parity with `markdown-merge`, not a separate blank-line design.

## Source of truth

For detailed behavior and rollout direction, follow:

- `../markdown-merge/BLANK_LINE_NORMALIZATION_PLAN.md`
- `markdown-merge/README.md`
- shared wrapper-facing specs and entry points

## Current evidence files

- `lib/commonmarker/merge/smart_merger.rb`
- `spec/commonmarker/merge/smart_merger_spec.rb`
- `README.md`

## Migration targets

- keep wrapper behavior aligned with `markdown-merge`
- preserve wrapper-level parity for blank-line-sensitive cases
- avoid wrapper-local spacing heuristics unless a backend-specific issue truly demands them

## Workstreams

- mirror shared Markdown-family blank-line behavior as it lands in `markdown-merge`
- extend parity specs when new family-level gap cases are added
- keep wrapper-specific code minimal

## Exit criteria

- wrapper behavior matches `markdown-merge` for the supported blank-line cases
- no unnecessary wrapper-local newline handling is introduced
