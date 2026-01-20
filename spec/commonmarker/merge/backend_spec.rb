# frozen_string_literal: true

require "spec_helper"

RSpec.describe Commonmarker::Merge::Backend do
  let(:backend) { described_class }

  # Store original state to restore after tests
  before do
    @original_load_attempted = backend.instance_variable_get(:@load_attempted)
    @original_loaded = backend.instance_variable_get(:@loaded)
  end

  after do
    # Restore original state
    backend.instance_variable_set(:@load_attempted, @original_load_attempted)
    backend.instance_variable_set(:@loaded, @original_loaded)
  end

  describe "::available?" do
    it "returns a boolean" do
      result = backend.available?
      expect(result).to be(true).or be(false)
    end

    it "memoizes the result" do
      first_result = backend.available?
      second_result = backend.available?
      expect(first_result).to eq(second_result)
    end

    context "when commonmarker gem is available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("commonmarker").and_return(true)
      end

      it "returns true" do
        expect(backend.available?).to be true
      end
    end

    context "when commonmarker gem is not available" do
      before do
        backend.reset!
        allow(backend).to receive(:require).with("commonmarker").and_raise(LoadError.new("cannot load commonmarker"))
      end

      it "returns false" do
        expect(backend.available?).to be false
      end
    end
  end

  describe "::reset!" do
    it "resets load state" do
      backend.available? # Trigger load
      backend.reset!
      expect(backend.instance_variable_get(:@load_attempted)).to be false
      expect(backend.instance_variable_get(:@loaded)).to be false
    end
  end

  describe "::capabilities" do
    context "when available" do
      before do
        allow(backend).to receive(:available?).and_return(true)
      end

      it "returns a hash with backend info" do
        caps = backend.capabilities
        expect(caps).to be_a(Hash)
        expect(caps[:backend]).to eq(:commonmarker)
        expect(caps[:query]).to be false
        expect(caps[:bytes_field]).to be false
        expect(caps[:incremental]).to be false
        expect(caps[:pure_ruby]).to be false
        expect(caps[:markdown_only]).to be true
        expect(caps[:error_tolerant]).to be true
      end
    end

    context "when not available" do
      before do
        allow(backend).to receive(:available?).and_return(false)
      end

      it "returns empty hash" do
        expect(backend.capabilities).to eq({})
      end
    end
  end

  describe "Language", :commonmarker_backend do
    describe "#initialize" do
      it "creates a language with default name :markdown" do
        lang = backend::Language.new
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:commonmarker)
        expect(lang.options).to eq({})
      end

      it "accepts custom name and options" do
        lang = backend::Language.new(:gfm, options: {smart: true})
        expect(lang.name).to eq(:gfm)
        expect(lang.options).to eq({smart: true})
      end
    end

    describe ".markdown" do
      it "creates a markdown language" do
        lang = backend::Language.markdown
        expect(lang.name).to eq(:markdown)
        expect(lang.backend).to eq(:commonmarker)
      end

      it "accepts options" do
        lang = backend::Language.markdown(options: {smart: true})
        expect(lang.options).to eq({smart: true})
      end
    end

    describe "#<=>" do
      it "compares by name" do
        lang1 = backend::Language.new(:a)
        lang2 = backend::Language.new(:b)
        expect(lang1 <=> lang2).to eq(-1)
      end

      it "returns nil for non-Language" do
        lang = backend::Language.new
        expect(lang <=> "other").to be_nil
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        lang = backend::Language.new(:markdown, options: {smart: true})
        expect(lang.inspect).to include("Language")
        expect(lang.inspect).to include("markdown")
      end
    end
  end

  describe "Parser", :commonmarker_backend do
    describe "#initialize" do
      it "creates a parser with nil language" do
        parser = backend::Parser.new
        expect(parser.language).to be_nil
      end
    end

    describe "#language=" do
      let(:parser) { backend::Parser.new }

      it "accepts a Language instance" do
        lang = backend::Language.markdown
        parser.language = lang
        expect(parser.language).to eq(lang)
      end
    end

    describe "#parse" do
      let(:parser) { backend::Parser.new }

      context "when language is not set" do
        it "raises an error" do
          expect { parser.parse("# Hello") }.to raise_error(RuntimeError, "Language not set")
        end
      end

      context "when commonmarker is not available" do
        before do
          parser.language = backend::Language.markdown
          allow(backend).to receive(:available?).and_return(false)
        end

        it "raises an error" do
          expect { parser.parse("# Hello") }.to raise_error(RuntimeError, "Commonmarker not available")
        end
      end

      context "when commonmarker is available" do
        let(:markdown_source) do
          <<~MD
            # Heading 1

            A paragraph with **bold** and *italic* text.

            ## Heading 2

            - Item 1
            - Item 2
            - Item 3

            ```ruby
            puts "Hello, World!"
            ```
          MD
        end

        before do
          parser.language = backend::Language.markdown
        end

        it "returns a Tree" do
          tree = parser.parse(markdown_source)
          expect(tree).to be_a(backend::Tree)
        end

        it "parses markdown document structure" do
          tree = parser.parse(markdown_source)
          root = tree.root_node
          expect(root.type).to eq("document")
        end
      end
    end

    describe "#parse_string" do
      let(:parser) { backend::Parser.new }

      before do
        parser.language = backend::Language.markdown
      end

      it "ignores old_tree parameter" do
        old_tree = double("old_tree")
        tree = parser.parse_string(old_tree, "# Hello")
        expect(tree).to be_a(backend::Tree)
      end
    end
  end

  describe "Tree", :commonmarker_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }
    let(:source) { "# Hello\n\nA paragraph." }
    let(:tree) { parser.parse(source) }

    describe "#root_node" do
      it "returns a Node" do
        expect(tree.root_node).to be_a(backend::Node)
      end

      it "returns document as root type" do
        expect(tree.root_node.type).to eq("document")
      end
    end

    describe "#errors" do
      it "returns an empty array" do
        expect(tree.errors).to eq([])
      end
    end

    describe "#warnings" do
      it "returns an empty array" do
        expect(tree.warnings).to eq([])
      end
    end

    describe "#comments" do
      it "returns an empty array" do
        expect(tree.comments).to eq([])
      end
    end

    describe "#inspect" do
      it "returns a descriptive string" do
        expect(tree.inspect).to include("Tree")
      end
    end
  end

  describe "Node", :commonmarker_backend do
    let(:parser) { backend::Parser.new.tap { |p| p.language = backend::Language.markdown } }

    describe "basic node properties" do
      let(:source) { "# Hello World\n\nA paragraph with **bold** text." }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#type" do
        it "returns node type as string" do
          expect(root.type).to eq("document")
        end
      end

      describe "#kind" do
        it "is aliased to type" do
          expect(root.kind).to eq(root.type)
        end
      end

      describe "#text" do
        it "returns node text content" do
          expect(root.text).to be_a(String)
        end
      end

      describe "#children" do
        it "returns array of child nodes" do
          children = root.children
          expect(children).to be_an(Array)
          expect(children).to all(be_a(backend::Node))
        end
      end

      describe "#child_count" do
        it "returns number of children" do
          expect(root.child_count).to be_a(Integer)
          expect(root.child_count).to be >= 0
        end
      end

      describe "#child" do
        it "returns child at index" do
          if root.child_count > 0
            expect(root.child(0)).to be_a(backend::Node)
          end
        end
      end

      describe "#first_child" do
        it "returns first child" do
          if root.child_count > 0
            expect(root.first_child).to be_a(backend::Node)
            expect(root.first_child).to eq(root.child(0))
          end
        end
      end

      describe "#each" do
        it "yields each child" do
          yielded = []
          root.each { |child| yielded << child }
          expect(yielded).to eq(root.children)
        end

        it "returns Enumerator when no block given" do
          expect(root.each).to be_an(Enumerator)
        end
      end
    end

    describe "position information" do
      let(:source) { "# Heading\n\nParagraph text." }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#start_point" do
        it "returns a Point" do
          point = root.start_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end
      end

      describe "#end_point" do
        it "returns a Point" do
          point = root.end_point
          expect(point).to respond_to(:row)
          expect(point).to respond_to(:column)
        end
      end

      describe "#start_line" do
        it "returns 1-based line number" do
          expect(root.start_line).to be_a(Integer)
          expect(root.start_line).to be >= 1
        end
      end

      describe "#end_line" do
        it "returns 1-based line number" do
          expect(root.end_line).to be_a(Integer)
          expect(root.end_line).to be >= 1
        end
      end

      describe "#start_byte" do
        it "returns byte offset" do
          expect(root.start_byte).to be_a(Integer)
          expect(root.start_byte).to be >= 0
        end
      end

      describe "#end_byte" do
        it "returns byte offset" do
          expect(root.end_byte).to be_a(Integer)
          expect(root.end_byte).to be >= 0
        end
      end
    end

    describe "node status" do
      let(:source) { "# Hello" }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#has_error?" do
        it "returns false for valid markdown" do
          expect(root.has_error?).to be false
        end
      end

      describe "#missing?" do
        it "returns false for present node" do
          expect(root.missing?).to be false
        end
      end

      describe "#named?" do
        it "returns boolean" do
          expect(root.named?).to be(true).or be(false)
        end
      end
    end

    describe "navigation" do
      let(:source) { "# Heading\n\nParagraph one.\n\nParagraph two." }
      let(:tree) { parser.parse(source) }
      let(:root) { tree.root_node }

      describe "#parent" do
        it "returns nil for root node" do
          expect(root.parent).to be_nil
        end

        it "returns parent for child nodes" do
          first_child = root.children.first
          expect(first_child.parent).to be_a(backend::Node) if first_child
        end
      end

      describe "#next_sibling" do
        it "returns next sibling when available" do
          children = root.children
          if children.size > 1
            expect(children.first.next_sibling).to be_a(backend::Node)
          end
        end
      end

      describe "#prev_sibling" do
        it "returns previous sibling when available" do
          children = root.children
          if children.size > 1
            expect(children.last.prev_sibling).to be_a(backend::Node)
          end
        end
      end
    end
  end

  describe "Point", :commonmarker_backend do
    let(:point) { backend::Point.new(row: 5, column: 10) }

    describe "#row" do
      it "returns row value" do
        expect(point.row).to eq(5)
      end
    end

    describe "#column" do
      it "returns column value" do
        expect(point.column).to eq(10)
      end
    end

    describe "#[]" do
      it "returns row for :row key" do
        expect(point[:row]).to eq(5)
      end

      it "returns column for :column key" do
        expect(point[:column]).to eq(10)
      end
    end

    describe "#to_h" do
      it "returns hash representation" do
        expect(point.to_h).to eq({row: 5, column: 10})
      end
    end

    describe "#to_s" do
      it "returns string representation" do
        expect(point.to_s).to eq("(5, 10)")
      end
    end

    describe "#inspect" do
      it "returns descriptive string" do
        expect(point.inspect).to include("Point")
        expect(point.inspect).to include("5")
        expect(point.inspect).to include("10")
      end
    end
  end

  describe "BackendRegistry integration" do
    it "registers availability checker with TreeHaver::BackendRegistry" do
      # The backend should have registered itself when loaded
      expect(TreeHaver::BackendRegistry.available?(:commonmarker)).to eq(backend.available?)
    end
  end
end
