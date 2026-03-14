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

    Markdown::Merge::WrapperSupport.install!(
      wrapper_module: self,
      require_prefix: "commonmarker/merge",
      default_freeze_token: "commonmarker-merge",
      default_inner_merge_code_blocks: false,
      registry_tag: :commonmarker_merge,
      merger_class: "Commonmarker::Merge::SmartMerger",
    )
  end
end

# Ensure backend is loaded and registered
Commonmarker::Merge.ensure_backend_loaded!


Commonmarker::Merge::Version.class_eval do
  extend VersionGem::Basic
end
