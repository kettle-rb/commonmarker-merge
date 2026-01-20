# frozen_string_literal: true

require "spec_helper"

# Integration tests specifically designed to cover uncovered branches
# in commonmarker-merge components.

RSpec.describe "Branch Coverage Integration" do
  describe "FileAligner edge cases" do
    describe "when template has duplicate signatures" do
      let(:template_md) do
        <<~MARKDOWN
          # Heading

          First paragraph.

          # Heading

          Second paragraph with same heading.
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Heading

          Destination paragraph.
        MARKDOWN
      end

      it "aligns duplicate signatures pairwise" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        aligner = Commonmarker::Merge::FileAligner.new(template_analysis, dest_analysis)

        alignment = aligner.align

        # Should have one match and one template-only
        matches = alignment.select { |e| e[:type] == :match }
        template_only = alignment.select { |e| e[:type] == :template_only }

        expect(matches.size).to be >= 1
        expect(template_only.size).to be >= 1
      end
    end

    describe "when dest has unique nodes not in template" do
      let(:template_md) do
        <<~MARKDOWN
          # Common Heading

          Template content.
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Common Heading

          Destination content.

          # Dest Only Heading

          This heading is only in destination.
        MARKDOWN
      end

      it "includes dest-only entries in alignment" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        aligner = Commonmarker::Merge::FileAligner.new(template_analysis, dest_analysis)

        alignment = aligner.align

        dest_only = alignment.select { |e| e[:type] == :dest_only }
        expect(dest_only).not_to be_empty
      end
    end

    describe "when signature is nil" do
      let(:template_md) { "Just a paragraph without any heading.\n" }
      let(:dest_md) { "Another paragraph without heading.\n" }

      it "handles nodes without signatures" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        aligner = Commonmarker::Merge::FileAligner.new(template_analysis, dest_analysis)

        # Should not raise
        alignment = aligner.align
        expect(alignment).to be_an(Array)
      end
    end
  end

  describe "ConflictResolver edge cases" do
    describe "when template node is a FreezeNode" do
      let(:template_md) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze -->
          ## Frozen in Template
          This is frozen content in template.
          <!-- commonmarker-merge:unfreeze -->

          After freeze.
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Heading

          ## Regular Section
          Destination content.
        MARKDOWN
      end

      it "handles FreezeNode from template" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        resolver = Commonmarker::Merge::ConflictResolver.new(
          preference: :destination,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )

        # Find freeze blocks in template
        freeze_blocks = template_analysis.freeze_blocks
        expect(freeze_blocks).not_to be_empty

        # Resolve with freeze node from template
        template_node = freeze_blocks.first
        dest_node = dest_analysis.statements.first

        result = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(result[:source]).to eq(:template)
        expect(result[:decision]).to eq(Commonmarker::Merge::ConflictResolver::DECISION_FROZEN)
      end
    end

    describe "when preference is :template" do
      let(:template_md) do
        <<~MARKDOWN
          # Heading

          Template paragraph content.
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Heading

          Destination paragraph content.
        MARKDOWN
      end

      it "prefers template when content differs" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        resolver = Commonmarker::Merge::ConflictResolver.new(
          preference: :template,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )

        # Index 0 = heading, 1 = gap_line, 2 = paragraph
        t_stmt = template_analysis.statements[2] # paragraph
        d_stmt = dest_analysis.statements[2] # paragraph

        result = resolver.resolve(t_stmt, d_stmt, template_index: 2, dest_index: 2)
        expect(result[:source]).to eq(:template)
        expect(result[:decision]).to eq(Commonmarker::Merge::ConflictResolver::DECISION_TEMPLATE)
      end
    end

    describe "node_to_text fallback to commonmark" do
      let(:template_md) { "# Heading\n\nParagraph.\n" }
      let(:dest_md) { "# Heading\n\nDifferent paragraph.\n" }

      it "handles nodes without source_position" do
        template_analysis = Commonmarker::Merge::FileAnalysis.new(template_md)
        dest_analysis = Commonmarker::Merge::FileAnalysis.new(dest_md)
        resolver = Commonmarker::Merge::ConflictResolver.new(
          preference: :destination,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )

        # Mock a node without source_position
        mock_node = double("MockNode")
        allow(mock_node).to receive_messages(
          source_position: nil,
          to_commonmark: "Rendered content",
        )

        # Access private method for testing
        text = resolver.send(:node_to_text, mock_node, template_analysis)
        expect(text).to eq("Rendered content")
      end
    end
  end

  describe "SmartMerger integration" do
    describe "with freeze blocks in destination" do
      let(:template_md) do
        <<~MARKDOWN
          # Project

          Template description.

          ## Features

          - Feature 1
          - Feature 2
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Project

          Custom description.

          <!-- commonmarker-merge:freeze Custom TOC -->
          ## Table of Contents

          - [Introduction](#intro)
          - [Usage](#usage)
          <!-- commonmarker-merge:unfreeze -->

          ## Features

          - Custom Feature
        MARKDOWN
      end

      it "preserves freeze blocks from destination" do
        merger = Commonmarker::Merge::SmartMerger.new(
          template_md,
          dest_md,
          preference: :template,
        )

        result = merger.merge_result
        result_text = result.content

        # Freeze block should be preserved
        expect(result_text).to include("commonmarker-merge:freeze")
        expect(result_text).to include("Table of Contents")
        expect(result_text).to include("commonmarker-merge:unfreeze")
      end
    end

    describe "with template-only nodes and add_template_only: true" do
      let(:template_md) do
        <<~MARKDOWN
          # Heading

          Template paragraph.

          ## Template Only Section

          This section is only in template.
        MARKDOWN
      end

      let(:dest_md) do
        <<~MARKDOWN
          # Heading

          Destination paragraph.
        MARKDOWN
      end

      it "adds template-only sections" do
        merger = Commonmarker::Merge::SmartMerger.new(
          template_md,
          dest_md,
          add_template_only_nodes: true,
        )

        result = merger.merge_result
        result_text = result.content

        expect(result_text).to include("Template Only Section")
      end
    end

    describe "with identical content" do
      let(:identical_md) do
        <<~MARKDOWN
          # Same Heading

          Same paragraph content.
        MARKDOWN
      end

      it "handles identical content efficiently" do
        merger = Commonmarker::Merge::SmartMerger.new(
          identical_md,
          identical_md,
        )

        result = merger.merge_result
        expect(result.content).to include("Same Heading")
      end
    end
  end

  describe "FileAnalysis edge cases" do
    describe "with unclosed freeze blocks" do
      let(:md_with_unclosed) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze -->
          This freeze block is never closed.
        MARKDOWN
      end

      it "handles unclosed freeze blocks gracefully" do
        analysis = Commonmarker::Merge::FileAnalysis.new(md_with_unclosed)
        # Should not raise, may or may not detect partial block
        expect(analysis.statements).to be_an(Array)
      end
    end

    describe "with nested-like comments" do
      let(:md_with_nested) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze -->
          Some content.
          <!-- This is a regular HTML comment -->
          More content.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "handles regular HTML comments inside freeze blocks" do
        analysis = Commonmarker::Merge::FileAnalysis.new(md_with_nested)
        expect(analysis.freeze_blocks.size).to eq(1)
      end
    end

    describe "with freeze block reason" do
      let(:md_with_reason) do
        <<~MARKDOWN
          # Heading

          <!-- commonmarker-merge:freeze Custom reason for freezing -->
          Frozen content.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "extracts the reason from freeze marker" do
        analysis = Commonmarker::Merge::FileAnalysis.new(md_with_reason)
        freeze_block = analysis.freeze_blocks.first

        expect(freeze_block.reason).to eq("Custom reason for freezing")
      end
    end
  end
end
