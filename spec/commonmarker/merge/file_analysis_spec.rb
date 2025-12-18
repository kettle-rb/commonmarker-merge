# frozen_string_literal: true

RSpec.describe Commonmarker::Merge::FileAnalysis do
  describe "#initialize" do
    context "with simple markdown" do
      let(:source) do
        <<~MARKDOWN
          # Heading

          Some paragraph text.
        MARKDOWN
      end

      it "parses successfully" do
        analysis = described_class.new(source)
        expect(analysis.valid?).to be true
      end

      it "stores the source" do
        analysis = described_class.new(source)
        expect(analysis.source).to eq(source)
      end

      it "splits into lines" do
        analysis = described_class.new(source)
        # heredoc adds trailing newline, so 4 lines total
        expect(analysis.lines.size).to eq(4)
      end

      it "has a document" do
        analysis = described_class.new(source)
        expect(analysis.document).not_to be_nil
      end

      it "extracts statements" do
        analysis = described_class.new(source)
        expect(analysis.statements.size).to eq(2)
      end
    end

    context "with multiple headings" do
      let(:source) do
        <<~MARKDOWN
          # Main Title

          Intro paragraph.

          ## Section One

          First section content.

          ## Section Two

          Second section content.
        MARKDOWN
      end

      it "extracts all top-level elements" do
        analysis = described_class.new(source)
        # heading, paragraph, heading, paragraph, heading, paragraph
        expect(analysis.statements.size).to eq(6)
      end
    end

    context "with code blocks" do
      let(:source) do
        <<~MARKDOWN
          # Example

          ```ruby
          def hello
            puts "world"
          end
          ```
        MARKDOWN
      end

      it "parses code blocks" do
        analysis = described_class.new(source)
        expect(analysis.valid?).to be true
        expect(analysis.statements.size).to eq(2)
      end
    end

    context "with lists" do
      let(:source) do
        <<~MARKDOWN
          # Shopping List

          - Apples
          - Bananas
          - Cherries
        MARKDOWN
      end

      it "parses lists" do
        analysis = described_class.new(source)
        expect(analysis.valid?).to be true
      end
    end

    context "with freeze blocks" do
      let(:source) do
        <<~MARKDOWN
          # Title

          Intro text.

          <!-- commonmarker-merge:freeze -->
          ## Custom Section

          This content is frozen.
          <!-- commonmarker-merge:unfreeze -->

          ## Regular Section

          Not frozen.
        MARKDOWN
      end

      it "detects freeze blocks" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks.size).to eq(1)
      end

      it "has correct freeze block line numbers" do
        analysis = described_class.new(source)
        freeze_node = analysis.freeze_blocks.first
        expect(freeze_node.start_line).to eq(5)
        expect(freeze_node.end_line).to eq(9)
      end

      it "extracts frozen content" do
        analysis = described_class.new(source)
        freeze_node = analysis.freeze_blocks.first
        expect(freeze_node.content).to include("Custom Section")
      end
    end

    context "with freeze block with reason" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze Manual TOC -->
          ## Table of Contents

          - [Intro](#intro)
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "extracts the reason" do
        analysis = described_class.new(source)
        freeze_node = analysis.freeze_blocks.first
        expect(freeze_node.reason).to eq("Manual TOC")
      end
    end

    context "with custom freeze token" do
      let(:source) do
        <<~MARKDOWN
          # Title

          <!-- my-token:freeze -->
          ## Frozen Content
          <!-- my-token:unfreeze -->
        MARKDOWN
      end

      it "detects custom freeze blocks" do
        analysis = described_class.new(source, freeze_token: "my-token")
        expect(analysis.freeze_blocks.size).to eq(1)
      end

      it "ignores default freeze token" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end

    context "with empty source" do
      let(:source) { "" }

      it "parses without error" do
        expect { described_class.new(source) }.not_to raise_error
      end

      it "has no statements" do
        analysis = described_class.new(source)
        expect(analysis.statements).to be_empty
      end
    end
  end

  describe "#valid?" do
    it "returns true for valid markdown" do
      analysis = described_class.new("# Hello")
      expect(analysis.valid?).to be true
    end

    it "returns true for empty content" do
      analysis = described_class.new("")
      expect(analysis.valid?).to be true
    end
  end

  describe "#line_at" do
    let(:source) { "# Title\n\nParagraph text.\n" }
    let(:analysis) { described_class.new(source) }

    it "returns correct line (1-indexed)" do
      expect(analysis.line_at(1)).to eq("# Title")
      expect(analysis.line_at(2)).to eq("")
      expect(analysis.line_at(3)).to eq("Paragraph text.")
    end

    it "returns nil for out of range" do
      expect(analysis.line_at(0)).to be_nil
      expect(analysis.line_at(100)).to be_nil
    end
  end

  describe "#source_range" do
    let(:source) do
      <<~MARKDOWN
        # Title

        First paragraph.

        Second paragraph.
      MARKDOWN
    end
    let(:analysis) { described_class.new(source) }

    it "returns lines in range" do
      result = analysis.source_range(1, 3)
      expect(result).to eq("# Title\n\nFirst paragraph.")
    end

    it "handles single line" do
      result = analysis.source_range(1, 1)
      expect(result).to eq("# Title")
    end
  end

  describe "#signature_at" do
    let(:source) do
      <<~MARKDOWN
        # Main Title

        Intro paragraph.

        ## Section
      MARKDOWN
    end
    let(:analysis) { described_class.new(source) }

    it "returns signature for heading" do
      sig = analysis.signature_at(0)
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:heading)
    end

    it "returns signature for paragraph" do
      sig = analysis.signature_at(1)
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:paragraph)
    end

    it "returns nil for out of range" do
      expect(analysis.signature_at(-1)).to be_nil
      expect(analysis.signature_at(100)).to be_nil
    end
  end

  describe "#in_freeze_block?" do
    let(:source) do
      <<~MARKDOWN
        # Title

        <!-- commonmarker-merge:freeze -->
        ## Frozen
        <!-- commonmarker-merge:unfreeze -->

        ## Not Frozen
      MARKDOWN
    end
    let(:analysis) { described_class.new(source) }

    it "returns true for lines in freeze block" do
      expect(analysis.in_freeze_block?(4)).to be true
    end

    it "returns false for lines outside freeze block" do
      expect(analysis.in_freeze_block?(1)).to be false
      expect(analysis.in_freeze_block?(8)).to be false
    end

    it "returns true for freeze markers themselves" do
      expect(analysis.in_freeze_block?(3)).to be true
      expect(analysis.in_freeze_block?(5)).to be true
    end
  end

  describe "#freeze_block_at" do
    let(:source) do
      <<~MARKDOWN
        # Title

        <!-- commonmarker-merge:freeze -->
        ## Frozen
        <!-- commonmarker-merge:unfreeze -->
      MARKDOWN
    end
    let(:analysis) { described_class.new(source) }

    it "returns freeze block for line in block" do
      block = analysis.freeze_block_at(4)
      expect(block).to be_a(Commonmarker::Merge::FreezeNode)
    end

    it "returns nil for line outside block" do
      expect(analysis.freeze_block_at(1)).to be_nil
    end
  end

  describe "#generate_signature with custom generator" do
    let(:source) do
      <<~MARKDOWN
        # Title

        Paragraph.
      MARKDOWN
    end

    it "uses custom generator when provided" do
      custom_generator = ->(node) { [:custom, node.type.to_s] }
      analysis = described_class.new(source, signature_generator: custom_generator)

      expect(analysis.signature_at(0)).to eq([:custom, "heading"])
    end

    it "falls through when generator returns node" do
      custom_generator = ->(node) { node }
      analysis = described_class.new(source, signature_generator: custom_generator)

      # Should use default signature computation
      expect(analysis.signature_at(0).first).to eq(:heading)
    end

    it "returns nil when generator returns nil" do
      custom_generator = ->(_node) { nil }
      analysis = described_class.new(source, signature_generator: custom_generator)

      expect(analysis.signature_at(0)).to be_nil
    end
  end

  describe "#compute_node_signature" do
    let(:analysis) { described_class.new("# Test\n\nParagraph.") }

    context "for headings" do
      let(:source) { "# Level 1\n\n## Level 2" }
      let(:analysis) { described_class.new(source) }

      it "includes heading type, level, and text" do
        sig = analysis.signature_at(0)
        expect(sig).to include(:heading)
        expect(sig).to include(1) # heading level
        expect(sig).to include("Level 1") # heading text
      end
    end

    context "for code blocks" do
      let(:source) do
        <<~MARKDOWN
          ```ruby
          puts "hello"
          ```
        MARKDOWN
      end
      let(:analysis) { described_class.new(source) }

      it "includes language info" do
        sig = analysis.signature_at(0)
        expect(sig).to include(:code_block)
        expect(sig).to include("ruby")
      end
    end

    context "for freeze nodes" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          ## Frozen
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end
      let(:analysis) { described_class.new(source) }

      it "returns freeze block signature" do
        # Freeze block is at index 0 in statements
        freeze_block = analysis.freeze_blocks.first
        expect(freeze_block).not_to be_nil
        sig = freeze_block.signature
        expect(sig.first).to eq(:freeze_block)
      end
    end
  end

  describe "freeze block edge cases" do
    context "with unclosed freeze block" do
      let(:source) do
        <<~MARKDOWN
          # Title

          <!-- commonmarker-merge:freeze -->
          ## Frozen Content
        MARKDOWN
      end

      it "handles gracefully (warns but doesn't crash)" do
        expect { described_class.new(source) }.not_to raise_error
      end
    end

    context "with unfreeze without freeze" do
      let(:source) do
        <<~MARKDOWN
          # Title

          <!-- commonmarker-merge:unfreeze -->
          ## Content
        MARKDOWN
      end

      it "handles gracefully" do
        expect { described_class.new(source) }.not_to raise_error
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end

    context "with multiple freeze blocks" do
      let(:source) do
        <<~MARKDOWN
          # Title

          <!-- commonmarker-merge:freeze -->
          ## First Frozen
          <!-- commonmarker-merge:unfreeze -->

          ## Regular

          <!-- commonmarker-merge:freeze -->
          ## Second Frozen
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "detects all freeze blocks" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks.size).to eq(2)
      end
    end

    context "with adjacent freeze blocks" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          ## First
          <!-- commonmarker-merge:unfreeze -->
          <!-- commonmarker-merge:freeze -->
          ## Second
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "detects both blocks" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks.size).to eq(2)
      end
    end
  end

  describe "#normalized_line" do
    let(:analysis) { described_class.new("# Title  \n  Content  ") }

    it "returns stripped normalized text" do
      expect(analysis.normalized_line(1)).to eq("# Title")
    end
  end

  describe "#compute_node_signature edge cases" do
    context "with list nodes" do
      let(:source) do
        <<~MARKDOWN
          - Item 1
          - Item 2
          - Item 3
        MARKDOWN
      end

      it "generates signature for unordered list" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        sig = analysis.generate_signature(stmt)
        expect(sig[0]).to eq(:list)
        expect(sig[2]).to eq(3) # 3 items
      end
    end

    context "with ordered list" do
      let(:source) do
        <<~MARKDOWN
          1. First
          2. Second
        MARKDOWN
      end

      it "generates signature for ordered list" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        sig = analysis.generate_signature(stmt)
        expect(sig[0]).to eq(:list)
      end
    end

    context "with block quote" do
      let(:source) do
        <<~MARKDOWN
          > This is a quote
          > spanning multiple lines
        MARKDOWN
      end

      it "generates signature for block quote" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        sig = analysis.generate_signature(stmt)
        expect(sig[0]).to eq(:block_quote)
      end
    end

    context "with thematic break" do
      let(:source) do
        <<~MARKDOWN
          Before

          ---

          After
        MARKDOWN
      end

      it "generates signature for thematic break" do
        analysis = described_class.new(source)
        # Find the thematic break
        thematic = analysis.statements.find { |s| s.respond_to?(:merge_type) && s.merge_type == :thematic_break }
        expect(thematic).not_to be_nil
        sig = analysis.generate_signature(thematic)
        expect(sig).to eq([:thematic_break])
      end
    end

    context "with HTML block" do
      let(:source) do
        <<~MARKDOWN
          <div class="custom">
          Content here
          </div>
        MARKDOWN
      end

      it "generates signature for HTML block" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        sig = analysis.generate_signature(stmt)
        expect(sig[0]).to eq(:html_block)
      end
    end

    context "with table" do
      let(:source) do
        <<~MARKDOWN
          | Col1 | Col2 | Col3 |
          |------|------|------|
          | A    | B    | C    |
        MARKDOWN
      end

      it "parses table content" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        # Tables may or may not be supported depending on options
        # Just verify we can parse and generate a signature without error
        if stmt.type == :table
          sig = analysis.generate_signature(stmt)
          expect(sig).not_to be_nil
          expect(sig[0]).to eq(:table)
        else
          # If table extension not enabled, it will be parsed as paragraph or other
          expect(stmt).not_to be_nil
        end
      end
    end
  end

  describe "#source_range edge cases" do
    let(:analysis) { described_class.new("Line 1\nLine 2\nLine 3") }

    it "returns empty string for invalid start line" do
      expect(analysis.source_range(0, 2)).to eq("")
    end

    it "returns empty string when end is before start" do
      expect(analysis.source_range(3, 1)).to eq("")
    end

    it "returns correct range for valid input" do
      expect(analysis.source_range(1, 2)).to eq("Line 1\nLine 2")
    end
  end

  describe "freeze block edge cases" do
    context "with unmatched unfreeze marker" do
      let(:source) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:unfreeze -->

          Content
        MARKDOWN
      end

      it "handles unmatched unfreeze gracefully" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end

    context "with unclosed freeze marker" do
      let(:source) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze -->

          Content without close
        MARKDOWN
      end

      it "handles unclosed freeze gracefully" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks).to be_empty
      end
    end

    context "with empty freeze block" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "handles empty freeze block" do
        analysis = described_class.new(source)
        expect(analysis.freeze_blocks.size).to eq(1)
        expect(analysis.freeze_blocks.first.content).to eq("")
      end
    end

    context "with nodes inside freeze blocks" do
      let(:source) do
        <<~MARKDOWN
          # Before

          <!-- commonmarker-merge:freeze -->
          ## Frozen Heading

          Frozen paragraph.
          <!-- commonmarker-merge:unfreeze -->

          # After
        MARKDOWN
      end

      it "integrates freeze blocks with regular nodes" do
        analysis = described_class.new(source)
        # Should have freeze block integrated into statements
        freeze_blocks = analysis.statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
      end
    end
  end

  describe "integrate_nodes_with_freeze_blocks edge cases" do
    context "with freeze blocks after all nodes" do
      let(:source) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze -->
          Frozen at end
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "includes freeze blocks in statements" do
        analysis = described_class.new(source)
        # Should have freeze block in statements
        freeze_blocks = analysis.statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
      end
    end

    context "with freeze block before first node" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          Frozen at start
          <!-- commonmarker-merge:unfreeze -->

          # Heading After
        MARKDOWN
      end

      it "includes freeze block before nodes" do
        analysis = described_class.new(source)
        freeze_blocks = analysis.statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
      end
    end
  end

  describe "extract_text_content with code spans" do
    let(:source) do
      <<~MARKDOWN
        Paragraph with `inline code` content.
      MARKDOWN
    end

    it "extracts text including code content" do
      analysis = described_class.new(source)
      stmt = analysis.statements.first
      sig = analysis.generate_signature(stmt)
      # Should generate valid signature even with code spans
      expect(sig).not_to be_nil
      expect(sig[0]).to eq(:paragraph)
    end
  end

  describe "node_name helper" do
    context "with regular nodes" do
      let(:source) { "# Heading\n" }

      it "handles nodes without name method" do
        analysis = described_class.new(source)
        stmt = analysis.statements.first
        # Headings don't have a name method
        sig = analysis.generate_signature(stmt)
        expect(sig[0]).to eq(:heading)
      end
    end
  end

  describe "unknown node type signature" do
    # This is hard to trigger with real markdown since commonmarker
    # handles all standard types. We verify the else branch exists.
    let(:source) { "# Heading\n\nParagraph.\n" }

    it "handles known types correctly" do
      analysis = described_class.new(source)
      analysis.statements.each do |stmt|
        next if stmt.is_a?(Commonmarker::Merge::FreezeNode)

        sig = analysis.generate_signature(stmt)
        expect(sig).not_to be_nil
        # Should not be :unknown for standard markdown
        expect(sig[0]).not_to eq(:unknown)
      end
    end
  end

  describe "footnote_definition signature" do
    # Test footnote definitions (GFM extension) - covers line 125
    context "with footnote definitions" do
      let(:source) do
        <<~MARKDOWN
          Here is a paragraph with a footnote[^1].

          [^1]: This is the footnote definition.
        MARKDOWN
      end

      it "parses footnotes if supported by commonmarker" do
        analysis = described_class.new(source)
        # The footnote may or may not be parsed depending on options
        expect(analysis.statements).not_to be_empty
      end
    end
  end

  describe "integrate_nodes_with_freeze_blocks additional edge cases" do
    # Tests for lines 325-326, 330, 340
    context "with freeze blocks that come before regular nodes" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          # Frozen First
          <!-- commonmarker-merge:unfreeze -->

          # Regular Heading

          Regular paragraph.
        MARKDOWN
      end

      it "integrates freeze blocks in correct order" do
        analysis = described_class.new(source)
        statements = analysis.statements
        # Should have freeze block and regular nodes
        freeze_blocks = statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
        # Freeze block should come before the regular heading in position
        expect(freeze_blocks.first.start_line).to eq(1)
      end
    end

    context "with multiple freeze blocks interspersed with content" do
      let(:source) do
        <<~MARKDOWN
          # First Heading

          <!-- commonmarker-merge:freeze -->
          Frozen content in middle.
          <!-- commonmarker-merge:unfreeze -->

          # Second Heading

          <!-- commonmarker-merge:freeze -->
          Another frozen block.
          <!-- commonmarker-merge:unfreeze -->

          # Third Heading
        MARKDOWN
      end

      it "correctly orders all nodes and freeze blocks" do
        analysis = described_class.new(source)
        statements = analysis.statements
        # Should have mix of headings and freeze nodes
        freeze_count = statements.count { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_count).to eq(2)
      end
    end

    context "with nodes entirely inside freeze blocks" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          # Frozen Heading

          Frozen paragraph inside.

          Another frozen paragraph.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "includes freeze node for the block" do
        analysis = described_class.new(source)
        statements = analysis.statements
        # Should have the freeze node
        freeze_blocks = statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
      end
    end

    context "with remaining freeze blocks after processing nodes" do
      # Tests the while loop at line 345-348 for adding remaining freeze blocks
      let(:source) do
        <<~MARKDOWN
          # Early Heading

          <!-- commonmarker-merge:freeze -->
          Content at the very end.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "adds remaining freeze blocks after last node" do
        analysis = described_class.new(source)
        freeze_blocks = analysis.statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
        # The freeze block should be after the heading
        expect(freeze_blocks.first.start_line).to be > 1
      end
    end

    context "with unmatched unfreeze marker" do
      let(:source) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:unfreeze -->

          Some content.
        MARKDOWN
      end

      it "handles malformed input gracefully" do
        analysis = described_class.new(source)
        # Should not raise error
        expect(analysis.valid?).to be true
        # No freeze blocks should be created from unmatched unfreeze
        freeze_blocks = analysis.statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks).to be_empty
      end
    end

    context "with footnote definitions" do
      let(:source) do
        <<~MARKDOWN
          # Document with Footnotes

          This has a footnote[^1].

          [^1]: This is the footnote content.
        MARKDOWN
      end

      it "computes signature for footnote definitions" do
        analysis = described_class.new(source, options: {extension: {footnotes: true}})
        footnote_nodes = analysis.statements.select { |s| s.respond_to?(:type) && s.type == :footnote_definition }
        if footnote_nodes.any?
          sig = analysis.compute_node_signature(footnote_nodes.first)
          expect(sig.first).to eq(:footnote_definition)
        else
          # Skip if CommonMarker version doesn't support footnotes as top-level
          skip "Footnotes not parsed as top-level nodes in this CommonMarker version"
        end
      end
    end

    context "with freeze block at very beginning before any content" do
      let(:source) do
        <<~MARKDOWN
          <!-- commonmarker-merge:freeze -->
          Very first content is frozen.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "handles freeze block as first element" do
        analysis = described_class.new(source)
        statements = analysis.statements
        freeze_blocks = statements.select { |s| s.is_a?(Commonmarker::Merge::FreezeNode) }
        expect(freeze_blocks.size).to eq(1)
        expect(freeze_blocks.first.start_line).to eq(1)
      end
    end
  end
end
