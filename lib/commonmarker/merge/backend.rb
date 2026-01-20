# frozen_string_literal: true

module Commonmarker
  module Merge
    # Commonmarker backend using the Commonmarker gem (comrak Rust parser)
    #
    # This backend wraps Commonmarker, a Ruby gem that provides bindings to
    # comrak, a fast CommonMark-compliant Markdown parser written in Rust.
    #
    # @note This backend only parses Markdown source code
    # @see https://github.com/gjtorikian/commonmarker Commonmarker gem
    #
    # @example Basic usage
    #   parser = TreeHaver::Parser.new
    #   parser.language = Commonmarker::Merge::Backend::Language.markdown
    #   tree = parser.parse(markdown_source)
    #   root = tree.root_node
    #   puts root.type  # => "document"
    module Backend
      @load_attempted = false
      @loaded = false

      # Check if the Commonmarker backend is available
      #
      # @return [Boolean] true if commonmarker gem is available
      class << self
        def available?
          return @loaded if @load_attempted # rubocop:disable ThreadSafety/ClassInstanceVariable
          @load_attempted = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          begin
            require "commonmarker"
            @loaded = true # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue LoadError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          rescue StandardError
            @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          end
          @loaded # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Reset the load state (primarily for testing)
        #
        # @return [void]
        # @api private
        def reset!
          @load_attempted = false # rubocop:disable ThreadSafety/ClassInstanceVariable
          @loaded = false # rubocop:disable ThreadSafety/ClassInstanceVariable
        end

        # Get capabilities supported by this backend
        #
        # @return [Hash{Symbol => Object}] capability map
        def capabilities
          return {} unless available?
          {
            backend: :commonmarker,
            query: false,
            bytes_field: false,       # Commonmarker uses line/column
            incremental: false,
            pure_ruby: false,         # Uses Rust via FFI
            markdown_only: true,
            error_tolerant: true,     # Markdown is forgiving
          }
        end
      end

      # Commonmarker language wrapper
      #
      # Commonmarker only parses Markdown. This class exists for API compatibility.
      #
      # @example
      #   language = Commonmarker::Merge::Backend::Language.markdown
      #   parser.language = language
      class Language < TreeHaver::Base::Language
        # Create a new Commonmarker language instance
        #
        # @param name [Symbol] Language name (should be :markdown)
        # @param options [Hash] Commonmarker parse options
        def initialize(name = :markdown, options: {})
          super(name, backend: :commonmarker, options: options)
        end

        class << self
          # Create a Markdown language instance
          #
          # @param options [Hash] Commonmarker parse options
          # @return [Language] Markdown language
          def markdown(options: {})
            new(:markdown, options: options)
          end

          # Load language from library path (API compatibility)
          #
          # @param _path [String] Ignored - Commonmarker doesn't load external grammars
          # @param symbol [String, nil] Ignored
          # @param name [String, nil] Language name hint (defaults to :markdown)
          # @return [Language] Markdown language
          # @raise [TreeHaver::NotAvailable] if requested language is not Markdown
          def from_library(_path = nil, symbol: nil, name: nil)
            lang_name = name || symbol&.to_s&.sub(/^tree_sitter_/, "")&.to_sym || :markdown

            unless lang_name == :markdown
              raise TreeHaver::NotAvailable,
                "Commonmarker backend only supports Markdown, not #{lang_name}."
            end

            markdown
          end
        end
      end

      # Commonmarker parser wrapper
      class Parser < TreeHaver::Base::Parser
        # Parse Markdown source code
        #
        # @param source [String] Markdown source to parse
        # @return [Tree] Parsed tree
        def parse(source)
          raise "Language not set" unless language
          Backend.available? or raise "Commonmarker not available"

          opts = language.options || {}
          doc = ::Commonmarker.parse(source, options: opts)
          Tree.new(doc, source)
        end
      end

      # Commonmarker tree wrapper
      class Tree < TreeHaver::Base::Tree
        def initialize(document, source)
          super(document, source: source)
        end

        def root_node
          Node.new(inner_tree, source: source, lines: lines)
        end
      end

      # Commonmarker node wrapper
      #
      # Wraps Commonmarker::Node to provide TreeHaver::Node-compatible interface.
      class Node < TreeHaver::Base::Node
        # Get the node type as a string
        #
        # @return [String] Node type
        def type
          inner_node.type.to_s
        end

        # Alias for TreeHaver compatibility
        alias_method :kind, :type

        # Get the text content of this node
        #
        # @return [String] Node text
        def text
          if inner_node.respond_to?(:string_content)
            begin
              content = inner_node.string_content.to_s
              return content unless content.empty?
            rescue TypeError
              # Container node - fall through
            end
          end
          children.map(&:text).join
        end

        # Get child nodes
        #
        # @return [Array<Node>] Child nodes
        def children
          return [] unless inner_node.respond_to?(:each)

          result = []
          inner_node.each { |child| result << Node.new(child, source: source, lines: lines) }
          result
        end

        # Get start byte offset
        def start_byte
          sp = start_point
          calculate_byte_offset(sp[:row], sp[:column])
        end

        # Get end byte offset
        def end_byte
          ep = end_point
          calculate_byte_offset(ep[:row], ep[:column])
        end

        # Get start point (0-based row/column)
        # @return [Point] Start position
        def start_point
          if inner_node.respond_to?(:source_position)
            begin
              pos = inner_node.source_position
              if pos && pos[:start_line]
                return Point.new(pos[:start_line] - 1, (pos[:start_column] || 1) - 1)
              end
            rescue
              nil
            end
          end

          # Fallback: check sourcepos (old API)
          begin
            pos = inner_node.sourcepos
            return Point.new(pos[0] - 1, pos[1] - 1) if pos
          rescue
            nil
          end

          Point.new(0, 0)
        end

        # Get end point (0-based row/column)
        # @return [Point] End position
        def end_point
          if inner_node.respond_to?(:source_position)
            begin
              pos = inner_node.source_position
              if pos && pos[:end_line]
                return Point.new(pos[:end_line] - 1, (pos[:end_column] || 1) - 1)
              end
            rescue
              nil
            end
          end

          begin
            pos = inner_node.sourcepos
            return Point.new(pos[2] - 1, pos[3] - 1) if pos
          rescue
            nil
          end

          Point.new(0, 0)
        end

        # Commonmarker-specific methods

        # Get heading level (1-6)
        # @return [Integer, nil]
        def header_level
          return unless type == "heading"
          begin
            inner_node.header_level
          rescue
            nil
          end
        end

        # Get fence info for code blocks
        # @return [String, nil]
        def fence_info
          return unless type == "code_block"
          begin
            inner_node.fence_info
          rescue
            nil
          end
        end

        # Get URL for links/images
        # @return [String, nil]
        def url
          inner_node.url
        rescue
          nil
        end

        # Get title for links/images
        # @return [String, nil]
        def title
          inner_node.title
        rescue
          nil
        end

        # Get the next sibling
        # @return [Node, nil]
        def next_sibling
          sibling = begin
            inner_node.next_sibling
          rescue
            nil
          end
          sibling ? Node.new(sibling, source: source, lines: lines) : nil
        end

        # Get the previous sibling
        # @return [Node, nil]
        def prev_sibling
          sibling = begin
            inner_node.previous_sibling
          rescue
            nil
          end
          sibling ? Node.new(sibling, source: source, lines: lines) : nil
        end

        # Get the parent node
        # @return [Node, nil]
        def parent
          p = begin
            inner_node.parent
          rescue
            nil
          end
          p ? Node.new(p, source: source, lines: lines) : nil
        end
      end

      # Alias Point to the base class for compatibility
      Point = TreeHaver::Base::Point

      # Register this backend with TreeHaver
      # Register for generic :markdown language
      ::TreeHaver.register_language(
        :markdown,
        backend_type: :commonmarker,
        backend_module: self,
        gem_name: "commonmarker",
      )

      # Register the full tag for RSpec dependency tags with require path
      # This enables tree_haver to lazily load this gem when checking availability
      ::TreeHaver::BackendRegistry.register_tag(
        :commonmarker_backend,
        category: :backend,
        backend_name: :commonmarker,
        require_path: "commonmarker/merge",
      ) { available? }
    end
  end
end
