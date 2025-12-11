# frozen_string_literal: true

module Commonmarker
  module Merge
    # Orchestrates the smart merge process for Markdown files using CommonMarker.
    #
    # Extends Markdown::Merge::SmartMergerBase with CommonMarker-specific parsing.
    #
    # Uses FileAnalysis, FileAligner, ConflictResolver, and MergeResult to
    # merge two Markdown files intelligently. Freeze blocks marked with
    # HTML comments are preserved exactly as-is.
    #
    # SmartMerger provides flexible configuration for different merge scenarios:
    # - Preserve destination customizations (default)
    # - Apply template updates
    # - Add new sections from template
    #
    # @example Basic merge (destination customizations preserved)
    #   merger = SmartMerger.new(template_content, dest_content)
    #   result = merger.merge
    #   if result.success?
    #     File.write("output.md", result.content)
    #   end
    #
    # @example Template updates win
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     preference: :template,
    #     add_template_only_nodes: true
    #   )
    #   result = merger.merge
    #
    # @example Custom signature matching
    #   sig_gen = ->(node) {
    #     if node.respond_to?(:type) && node.type == :heading
    #       [:heading, node.header_level]  # Match by level only, not content
    #     else
    #       node  # Fall through to default
    #     end
    #   }
    #   merger = SmartMerger.new(
    #     template_content,
    #     dest_content,
    #     signature_generator: sig_gen
    #   )
    #
    # @see FileAnalysis
    # @see Markdown::Merge::SmartMergerBase
    class SmartMerger < Markdown::Merge::SmartMergerBase
      # Creates a new SmartMerger for intelligent Markdown file merging.
      #
      # @param template_content [String] Template Markdown source code
      # @param dest_content [String] Destination Markdown source code
      #
      # @param signature_generator [Proc, nil] Optional proc to generate custom node signatures.
      #   The proc receives a Commonmarker::Node and should return one of:
      #   - An array representing the node's signature
      #   - `nil` to indicate the node should have no signature
      #   - The original node to fall through to default signature computation
      #
      # @param preference [Symbol] Controls which version to use when nodes
      #   have matching signatures but different content:
      #   - `:destination` (default) - Use destination version (preserves customizations)
      #   - `:template` - Use template version (applies updates)
      #
      # @param add_template_only_nodes [Boolean] Controls whether to add nodes that only
      #   exist in template:
      #   - `false` (default) - Skip template-only nodes
      #   - `true` - Add template-only nodes to result
      #
      # @param freeze_token [String] Token to use for freeze block markers.
      #   Default: "commonmarker-merge"
      #   Looks for: <!-- commonmarker-merge:freeze --> / <!-- commonmarker-merge:unfreeze -->
      #
      # @param options [Hash] CommonMarker parse options
      #
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching of
      #   unmatched nodes. Default: nil (fuzzy matching disabled).
      #   Set to TableMatchRefiner.new to enable fuzzy table matching.
      #
      # @raise [TemplateParseError] If template has syntax errors
      # @raise [DestinationParseError] If destination has syntax errors
      def initialize(
        template_content,
        dest_content,
        signature_generator: nil,
        preference: :destination,
        add_template_only_nodes: false,
        freeze_token: FileAnalysis::DEFAULT_FREEZE_TOKEN,
        options: {},
        match_refiner: nil
      )
        @options = options
        super(
          template_content,
          dest_content,
          signature_generator: signature_generator,
          preference: preference,
          add_template_only_nodes: add_template_only_nodes,
          inner_merge_code_blocks: false,
          freeze_token: freeze_token,
          match_refiner: match_refiner,
          options: options,
        )
      end

      # Create a FileAnalysis instance for CommonMarker parsing.
      #
      # @param content [String] Markdown content to analyze
      # @param options [Hash] Analysis options
      # @return [FileAnalysis] CommonMarker-specific file analysis
      def create_file_analysis(content, **opts)
        FileAnalysis.new(
          content,
          freeze_token: opts[:freeze_token],
          signature_generator: opts[:signature_generator],
          options: opts[:options] || @options,
        )
      end

      # Returns the TemplateParseError class to use.
      #
      # @return [Class] Commonmarker::Merge::TemplateParseError
      def template_parse_error_class
        TemplateParseError
      end

      # Returns the DestinationParseError class to use.
      #
      # @return [Class] Commonmarker::Merge::DestinationParseError
      def destination_parse_error_class
        DestinationParseError
      end

      # Convert a node to its source text.
      #
      # @param node [Object] Node to convert
      # @param analysis [FileAnalysis] Analysis for source lookup
      # @return [String] Source text
      def node_to_source(node, analysis)
        # Check for any FreezeNode type (base class or subclass)
        if node.is_a?(Ast::Merge::FreezeNodeBase)
          node.full_text
        else
          pos = node.source_position
          start_line = pos&.dig(:start_line)
          end_line = pos&.dig(:end_line)

          return node.to_commonmark unless start_line && end_line

          analysis.source_range(start_line, end_line)
        end
      end
    end
  end
end
