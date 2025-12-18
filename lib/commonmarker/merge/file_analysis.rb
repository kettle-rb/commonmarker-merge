# frozen_string_literal: true

module Commonmarker
  module Merge
    # File analysis for Markdown files using CommonMarker.
    #
    # This is a thin wrapper around Markdown::Merge::FileAnalysis that:
    # - Forces the :commonmarker backend
    # - Sets the default freeze token to "commonmarker-merge"
    # - Exposes commonmarker-specific options
    #
    # @example Basic usage
    #   analysis = FileAnalysis.new(markdown_source)
    #   analysis.statements.each do |node|
    #     puts "#{node.merge_type}: #{node.type}"
    #   end
    #
    # @example With custom freeze token
    #   analysis = FileAnalysis.new(source, freeze_token: "my-merge")
    #
    # @see Markdown::Merge::FileAnalysis Underlying implementation
    class FileAnalysis < Markdown::Merge::FileAnalysis
      # Default freeze token for commonmarker-merge
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "commonmarker-merge"

      # Initialize file analysis with CommonMarker backend.
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers (default: "commonmarker-merge")
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param options [Hash] CommonMarker parse options
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, options: {})
        super(
          source,
          backend: :commonmarker,
          freeze_token: freeze_token,
          signature_generator: signature_generator,
          options: options,
        )
      end

      # Returns the FreezeNode class to use.
      #
      # @return [Class] Commonmarker::Merge::FreezeNode
      def freeze_node_class
        FreezeNode
      end
    end
  end
end
