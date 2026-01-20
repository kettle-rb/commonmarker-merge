# frozen_string_literal: true

# Hard dependency - ensures commonmarker gem is installed
require "commonmarker"

# External gems
require "version_gem"

# Shared merge infrastructure (includes tree_haver)
require "markdown/merge"

# This gem
require_relative "merge/version"

module Commonmarker
  # Smart merging for Markdown files using CommonMarker AST.
  #
  # Commonmarker::Merge provides intelligent merging of Markdown files by:
  # - Parsing Markdown into AST using CommonMarker via tree_haver
  # - Matching structural elements (headings, paragraphs, lists, etc.) between files
  # - Preserving frozen sections marked with HTML comments
  # - Resolving conflicts based on configurable preferences
  #
  # This is a thin wrapper around Markdown::Merge that:
  # - Provides hard dependency on the commonmarker gem
  # - Sets commonmarker-specific defaults (freeze token, inner_merge_code_blocks)
  # - Maintains API compatibility for existing users
  #
  # @example Basic merge
  #   merger = Commonmarker::Merge::SmartMerger.new(template, destination)
  #   result = merger.merge
  #   puts result.content if result.success?
  #
  # @example With freeze blocks
  #   # In your Markdown file:
  #   # <!-- commonmarker-merge:freeze -->
  #   # ## Custom Section
  #   # This content is preserved during merges.
  #   # <!-- commonmarker-merge:unfreeze -->
  #
  # @see SmartMerger Main entry point for merging
  # @see Markdown::Merge::SmartMerger Underlying implementation
  module Merge
    # Base error class for Commonmarker::Merge
    # Inherits from Markdown::Merge::Error for consistency across merge gems.
    class Error < Markdown::Merge::Error; end

    # Raised when a Markdown file has parsing errors.
    # Inherits from Markdown::Merge::ParseError for consistency across merge gems.
    class ParseError < Markdown::Merge::ParseError; end

    # Raised when the template file has syntax errors.
    class TemplateParseError < ParseError; end

    # Raised when the destination file has syntax errors.
    class DestinationParseError < ParseError; end

    # Default freeze token for commonmarker-merge
    # @return [String]
    DEFAULT_FREEZE_TOKEN = "commonmarker-merge"

    # Default inner_merge_code_blocks setting for commonmarker-merge
    # @return [Boolean]
    DEFAULT_INNER_MERGE_CODE_BLOCKS = false

    # Re-export shared classes from markdown-merge
    FileAligner = Markdown::Merge::FileAligner
    ConflictResolver = Markdown::Merge::ConflictResolver
    MergeResult = Markdown::Merge::MergeResult
    TableMatchAlgorithm = Markdown::Merge::TableMatchAlgorithm
    TableMatchRefiner = Markdown::Merge::TableMatchRefiner
    CodeBlockMerger = Markdown::Merge::CodeBlockMerger
    NodeTypeNormalizer = Markdown::Merge::NodeTypeNormalizer

    autoload :DebugLogger, "commonmarker/merge/debug_logger"
    autoload :FreezeNode, "commonmarker/merge/freeze_node"
    autoload :FileAnalysis, "commonmarker/merge/file_analysis"
    autoload :SmartMerger, "commonmarker/merge/smart_merger"
    autoload :Backend, "commonmarker/merge/backend"

    class << self
      # Eagerly load and register backend when this module is loaded
      # This ensures the backend is available for tree_haver before any parsing happens
      def ensure_backend_loaded!
        Backend # Access constant to trigger autoload
      end
    end
  end
end

# Ensure backend is loaded and registered
Commonmarker::Merge.ensure_backend_loaded!

# Register with ast-merge's MergeGemRegistry for RSpec dependency tags
# Only register if MergeGemRegistry is loaded (i.e., in test environment)
if defined?(Ast::Merge::RSpec::MergeGemRegistry)
  Ast::Merge::RSpec::MergeGemRegistry.register(
    :commonmarker_merge,
    require_path: "commonmarker/merge",
    merger_class: "Commonmarker::Merge::SmartMerger",
    test_source: "# Test\n\nParagraph",
    category: :markdown,
  )
end

Commonmarker::Merge::Version.class_eval do
  extend VersionGem::Basic
end
