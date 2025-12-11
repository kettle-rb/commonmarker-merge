# frozen_string_literal: true

module Commonmarker
  module Merge
    # File analysis for Markdown files using CommonMarker.
    #
    # Extends Markdown::Merge::FileAnalysisBase with CommonMarker-specific parsing.
    #
    # Parses Markdown source code and extracts:
    # - Top-level block elements (headings, paragraphs, lists, code blocks, etc.)
    # - Freeze blocks marked with HTML comments
    # - Structural signatures for matching elements between files
    #
    # Freeze blocks are marked with HTML comments:
    #   <!-- commonmarker-merge:freeze -->
    #   ... content to preserve ...
    #   <!-- commonmarker-merge:unfreeze -->
    #
    # @example Basic usage
    #   analysis = FileAnalysis.new(markdown_source)
    #   analysis.statements.each do |node|
    #     puts "#{node.class}: #{node.type rescue 'freeze'}"
    #   end
    #
    # @example With custom freeze token
    #   analysis = FileAnalysis.new(source, freeze_token: "my-merge")
    #   # Looks for: <!-- my-merge:freeze --> / <!-- my-merge:unfreeze -->
    #
    # @see Markdown::Merge::FileAnalysisBase Base class
    class FileAnalysis < Markdown::Merge::FileAnalysisBase
      # Default freeze token for identifying freeze blocks
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "commonmarker-merge"

      # Initialize file analysis with CommonMarker parser
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers (default: "commonmarker-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param options [Hash] CommonMarker parse options
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, options: {})
        @options = options
        super(source, freeze_token: freeze_token, signature_generator: signature_generator)
      end

      # Parse the source document using CommonMarker.
      #
      # @param source [String] Markdown source to parse
      # @return [Commonmarker::Node] Root document node
      def parse_document(source)
        Commonmarker.parse(source, options: @options)
      end

      # Get the next sibling of a node.
      #
      # CommonMarker uses next_sibling.
      #
      # @param node [Commonmarker::Node] Current node
      # @return [Commonmarker::Node, nil] Next sibling or nil
      def next_sibling(node)
        node.next_sibling
      end

      # Returns the FreezeNode class to use.
      #
      # @return [Class] Commonmarker::Merge::FreezeNode
      def freeze_node_class
        FreezeNode
      end

      # Check if value is a CommonMarker node.
      #
      # @param value [Object] Value to check
      # @return [Boolean] true if this is a CommonMarker node
      def parser_node?(value)
        value.is_a?(Commonmarker::Node)
      end

      # Override to detect CommonMarker nodes for signature generator fallthrough
      # @param value [Object] The value to check
      # @return [Boolean] true if this is a fallthrough node
      def fallthrough_node?(value)
        value.is_a?(Commonmarker::Node) || value.is_a?(FreezeNode) || super
      end

      # Compute signature for a CommonMarker node.
      #
      # Maps CommonMarker-specific node types to canonical signatures.
      #
      # @param node [Commonmarker::Node] The node
      # @return [Array, nil] Signature array
      def compute_parser_signature(node)
        type = node.type
        case type
        when :heading
          # Content-based: Match headings by level and text content
          [:heading, node.header_level, extract_text_content(node)]
        when :paragraph
          # Content-based: Match paragraphs by content hash (first 32 chars of digest)
          text = extract_text_content(node)
          [:paragraph, Digest::SHA256.hexdigest(text)[0, 32]]
        when :code_block
          # Content-based: Match code blocks by fence info and content hash
          content = safe_string_content(node)
          [:code_block, node.fence_info, Digest::SHA256.hexdigest(content)[0, 16]]
        when :list
          # Structure-based: Match lists by type and item count (content may differ)
          [:list, node.list_type, count_children(node)]
        when :block_quote
          # Content-based: Match block quotes by content hash
          text = extract_text_content(node)
          [:block_quote, Digest::SHA256.hexdigest(text)[0, 16]]
        when :thematic_break
          # Structure-based: All thematic breaks are equivalent
          [:thematic_break]
        when :html_block
          # Content-based: Match HTML blocks by content hash
          content = safe_string_content(node)
          [:html_block, Digest::SHA256.hexdigest(content)[0, 16]]
        when :table
          # Content-based: Match tables by structure and header content
          header_content = extract_table_header_content(node)
          [:table, count_children(node), Digest::SHA256.hexdigest(header_content)[0, 16]]
        when :footnote_definition
          # Name-based: Match footnotes by name
          [:footnote_definition, node_name(node)]
        else
          # :nocov: defensive - CommonMarker only produces known node types
          # Unknown type - use type and position
          pos = node.source_position
          [:unknown, type, pos&.dig(:start_line)]
          # :nocov:
        end
      end

      private

      # Get node name (for footnotes, etc.)
      # @param node [Commonmarker::Node] The node
      # @return [String, nil] Node name
      def node_name(node)
        node.respond_to?(:name) ? node.name : nil
      end
    end
  end
end
