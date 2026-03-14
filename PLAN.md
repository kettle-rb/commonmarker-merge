# PLAN.md

## Goal
Adopt the shared Comment AST & Merge capability in `commonmarker-merge` by inheriting as much as possible from `markdown-merge` and keeping this gem a thin backend wrapper.

`psych-merge` is the reference for the shared comment API, but `markdown-merge` is the immediate dependency baseline for this plan.

## Current Status
- `commonmarker-merge` should stay wrapper-thin and avoid duplicating Markdown-core logic.
- The gem has the standard merge-gem layout and should primarily express backend wiring, defaults, and integration coverage.
- Any meaningful comment merge behavior should land in `markdown-merge` first and then be adopted here.
- The main job for this gem is backend parity, not a custom comment model.
- Wrapper passthrough for standalone HTML comment helpers and backend-specific parity fixtures is now in place.

## Integration Strategy
- Wait for the core Markdown comment capability to stabilize in `markdown-merge`.
- Expose the shared capability through wrapper analysis / merger entry points.
- Add only backend-specific normalization needed for Commonmarker positions or node behavior.
- Keep wrapper-level behavior focused on defaults, backend wiring, and integration coverage.

## First Slices
1. Track `markdown-merge` progress and avoid duplicating core work here.
2. Once core support exists, expose the shared comment capability through this wrapper.
3. Add wrapper integration specs that prove standalone comment regions survive through Commonmarker-backed merges.
4. Fix only backend-specific ownership or range issues that block parity.

## First Files To Inspect
- `lib/commonmarker/merge/file_analysis.rb`
- `lib/commonmarker/merge/smart_merger.rb`
- any backend wiring under `lib/commonmarker/merge/`
- wrapper-focused specs under `spec/commonmarker/merge/`

## Tests To Add First
- backend integration specs after `markdown-merge` support lands
- wrapper smart merger specs for standalone comment regions
- parity fixtures shared with `markdown-merge`
- targeted regressions only for Commonmarker-specific range/ownership issues

## Risks
- Duplicating core logic here would create drift from `markdown-merge`.
- Backend range differences may still require thin normalization.
- Wrapper defaults must not accidentally diverge from the shared Markdown plan.
- The plan should remain intentionally smaller than the Markdown-core plan.

## Success Criteria
- This wrapper stays thin.
- Shared comment capability flows through from `markdown-merge` with minimal extra code.
- Commonmarker-specific range issues are covered without creating a second comment system.
- Wrapper integration specs prove parity with the core Markdown behavior.

## Rollout Phase
- Phase 3 target.
- Start only after the Markdown-core plan is stable enough to inherit.

## Latest `ast-merge` Comment Logic Checklist (2026-03-13)
- [x] Shared capability passthrough: expose Markdown-core-style `comment_capability` / `comment_augmenter` through wrapper entry points
- [~] Document boundary parity: standalone HTML comment helper surface is exposed; broader ownership parity still remains
- [x] Matched-node fallback parity: wrapper coverage now preserves destination standalone-comment fallback under template-preferred fuzzy paragraph matching
- [x] Removed-node parity: wrapper replace-mode coverage now preserves standalone HTML comments during partial-template replacement
- [x] Backend parity fixtures: focused Commonmarker wrapper regressions are in place for matched-node and replace-mode standalone-comment preservation

Current parity status: focused wrapper parity is validated end-to-end; local workspace gem wiring now also follows the shared `nomono` path-override pattern used by sibling repos. Broader Markdown-family consolidation still remains.
Next execution target: keep future work narrow to true Commonmarker-specific ownership/range gaps or shared-core consolidation rather than wrapper bootstrap repair.

## Progress
- 2026-03-13: Wrapper-thinning consolidation completed.
- Replaced the duplicated local standalone HTML `CommentTracker`, wrapper-local file-analysis comment passthrough methods, and wrapper-local replace-mode standalone-comment helper overrides in `PartialTemplateMerger` with direct reuse of the shared Markdown-core implementations.
- Revalidated `spec/commonmarker/merge_spec.rb`, `spec/commonmarker/merge/file_analysis_spec.rb`, and `spec/commonmarker/merge/partial_template_merger_integration_spec.rb`, then revalidated the full `commonmarker-merge` suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`93 examples, 0 failures, 1 pending` focused; `21 examples, 0 failures` partial-template rerun; `431 examples, 0 failures, 1 pending` full).

## Execution Backlog

### Slice 1 — Wrapper passthrough
- Expose the shared comment capability through the wrapper once `markdown-merge` provides it.
- Add small integration specs proving standalone comment regions survive Commonmarker-backed merges.
- Keep the wrapper code thin and configuration-focused.

### Slice 2 — Backend-specific normalization only
- Fix only Commonmarker-specific range or ownership issues that block parity.
- Reuse shared Markdown fixtures wherever possible.
- Avoid introducing wrapper-local comment algorithms.

### Slice 3 — Freeze defaults and integration polish
- Re-check wrapper defaults, freeze behavior, and partial-merge integration against the new comment capability.
- Add only a small number of wrapper-specific regressions if needed.

## Dependencies / Resume Notes
- Do not start here until sibling `markdown-merge/PLAN.md` Slice 2 is stable.
- Inspect `lib/commonmarker/merge/file_analysis.rb` and wrapper integration specs first.
- Parity with `markdown-merge` matters more than wrapper cleverness.

## Exit Gate For This Plan
- The wrapper remains thin while proving backend-correct parity with the Markdown core comment behavior.
