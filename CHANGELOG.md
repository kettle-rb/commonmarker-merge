# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

### Changed

- **SmartMerger**: Added `**extra_options` for forward compatibility
  - Accepts additional options that may be added to base class in future
  - Passes all options through to `Markdown::Merge::SmartMerger`

### Deprecated

### Removed

### Fixed

### Security

## [1.0.0] - 2024-12-17

### Added

- Initial release of commonmarker-merge
- Thin wrapper around `markdown-merge` for Commonmarker backend
- `Commonmarker::Merge::SmartMerger` - smart merging with commonmarker defaults
  - Default freeze token: `"commonmarker-merge"`
  - Default `inner_merge_code_blocks: false`
- `Commonmarker::Merge::FileAnalysis` - file analysis with commonmarker backend
- `Commonmarker::Merge::FreezeNode` - freeze block support
- Commonmarker-specific parse options via `options:` parameter
- Error classes: `Error`, `ParseError`, `TemplateParseError`, `DestinationParseError`
- Re-exports shared classes from markdown-merge:
  - `FileAligner`, `ConflictResolver`, `MergeResult`
  - `TableMatchAlgorithm`, `TableMatchRefiner`, `CodeBlockMerger`
  - `NodeTypeNormalizer`

### Dependencies

- `commonmarker` (~> 2.0) - Comrak Rust parser
- `markdown-merge` (~> 1.0) - central merge infrastructure
- `version_gem` (~> 1.1)

[Unreleased]: https://github.com/kettle-rb/commonmarker-merge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/commonmarker-merge/compare/12d4e9fff5bbe6a9b29e81c6643b4dd705f8e80a...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/commonmarker-merge/tags/v1.0.0
