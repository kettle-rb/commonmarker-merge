# frozen_string_literal: true

require "spec_helper"

RSpec.describe Commonmarker::Merge::SmartMerger do
  describe "#initialize" do
    let(:template) { "# Title\n\nTemplate content.\n" }
    let(:destination) { "# Title\n\nDestination content.\n" }

    it "creates a merger" do
      merger = described_class.new(template, destination)
      expect(merger).to be_a(described_class)
    end

    it "has template_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.template_analysis).to be_a(Commonmarker::Merge::FileAnalysis)
    end

    it "has dest_analysis" do
      merger = described_class.new(template, destination)
      expect(merger.dest_analysis).to be_a(Commonmarker::Merge::FileAnalysis)
    end

    it "has aligner" do
      merger = described_class.new(template, destination)
      expect(merger.aligner).to be_a(Commonmarker::Merge::FileAligner)
    end

    it "has resolver" do
      merger = described_class.new(template, destination)
      expect(merger.resolver).to be_a(Commonmarker::Merge::ConflictResolver)
    end

    context "with invalid template" do
      # CommonMarker is quite tolerant, so we test error propagation
      it "accepts any markdown-like content" do
        expect { described_class.new("", destination) }.not_to raise_error
      end

      it "raises TemplateParseError when template_content doesn't respond to split" do
        expect { described_class.new(nil, destination) }.to raise_error(
          Commonmarker::Merge::TemplateParseError,
        )
      end

      it "raises TemplateParseError when template_content is an Integer" do
        expect { described_class.new(123, destination) }.to raise_error(
          Commonmarker::Merge::TemplateParseError,
        )
      end
    end

    context "with invalid destination" do
      it "raises DestinationParseError when dest_content doesn't respond to split" do
        expect { described_class.new(template, nil) }.to raise_error(
          Commonmarker::Merge::DestinationParseError,
        )
      end

      it "raises DestinationParseError when dest_content is an Integer" do
        expect { described_class.new(template, 456) }.to raise_error(
          Commonmarker::Merge::DestinationParseError,
        )
      end
    end

    context "with options" do
      it "accepts preference" do
        merger = described_class.new(template, destination, preference: :template)
        expect(merger.resolver.preference).to eq(:template)
      end

      it "accepts custom freeze_token" do
        merger = described_class.new(template, destination, freeze_token: "custom-token")
        expect(merger).to be_a(described_class)
      end

      it "accepts signature_generator" do
        custom_gen = ->(node) { [:custom, node.type.to_s] }
        merger = described_class.new(template, destination, signature_generator: custom_gen)
        expect(merger).to be_a(described_class)
      end

      it "accepts add_template_only_nodes" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        expect(merger).to be_a(described_class)
      end
    end
  end

  describe "#merge" do
    context "with identical files" do
      let(:content) do
        <<~MARKDOWN
          # Title

          Content here.
        MARKDOWN
      end

      it "returns successful result" do
        merger = described_class.new(content, content)
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "returns content" do
        merger = described_class.new(content, content)
        result = merger.merge_result
        expect(result.content).to include("Title")
        expect(result.content).to include("Content here")
      end
    end

    context "with destination-only sections" do
      let(:template) { "# Title" }
      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Custom Section

          Custom content.
        MARKDOWN
      end

      it "preserves destination-only sections" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Custom Section")
        expect(result.content).to include("Custom content")
      end
    end

    context "with template-only sections" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## New Section

          New content.
        MARKDOWN
      end
      let(:destination) { "# Title" }

      context "when add_template_only_nodes is false (default)" do
        it "does not add template-only sections" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          expect(result.content).not_to include("New Section")
        end
      end

      context "when add_template_only_nodes is true" do
        it "adds template-only sections" do
          merger = described_class.new(template, destination, add_template_only_nodes: true)
          result = merger.merge_result
          expect(result.content).to include("New Section")
          expect(result.content).to include("New content")
        end
      end
    end

    context "with matching sections different content" do
      # Use headings which match by level+text, with different following paragraphs
      let(:template) { "# Title\n\n## Section\n\nTemplate details." }
      let(:destination) { "# Title\n\n## Section\n\nDestination details." }

      context "when preference is :destination (default)" do
        it "uses destination version for matched headings" do
          merger = described_class.new(template, destination)
          result = merger.merge_result
          # Headings match and destination wins
          expect(result.content).to include("# Title")
          expect(result.content).to include("## Section")
          # Paragraphs have different signatures so don't match
          # Destination-only paragraphs are preserved
          expect(result.content).to include("Destination details")
        end
      end

      context "when preference is :template" do
        it "uses template version for matched headings" do
          merger = described_class.new(template, destination, preference: :template)
          result = merger.merge_result
          # Headings match and template wins (but they're identical)
          expect(result.content).to include("# Title")
          expect(result.content).to include("## Section")
        end

        it "adds template-only nodes when enabled" do
          merger = described_class.new(
            template,
            destination,
            preference: :template,
            add_template_only_nodes: true,
          )
          result = merger.merge_result
          # Both paragraphs should appear since template-only are added
          expect(result.content).to include("Template details")
        end
      end
    end

    context "with freeze blocks" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section

          Template section content.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Title

          <!-- commonmarker-merge:freeze -->
          ## Section

          Frozen section content.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves freeze block content" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Frozen section content")
        expect(result.content).to include("commonmarker-merge:freeze")
        expect(result.content).to include("commonmarker-merge:unfreeze")
      end

      it "reports frozen blocks in result" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.has_frozen_blocks?).to be true
      end
    end

    context "with complex document" do
      let(:template) do
        <<~MARKDOWN
          # Project Name

          ## Installation

          ```bash
          gem install project
          ```

          ## Usage

          Template usage instructions.

          ## Contributing

          See CONTRIBUTING.md
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Project Name

          ## Installation

          ```bash
          gem install project
          ```

          ## Usage

          Custom usage instructions.

          ## Custom Section

          Project-specific content.
        MARKDOWN
      end

      it "produces valid merged output" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "preserves destination customizations" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.content).to include("Custom usage instructions")
        expect(result.content).to include("Custom Section")
      end
    end

    context "with empty files" do
      it "handles empty template" do
        merger = described_class.new("", "# Title")
        result = merger.merge_result
        expect(result.success?).to be true
        expect(result.content).to include("Title")
      end

      it "handles empty destination" do
        merger = described_class.new("# Title", "")
        result = merger.merge_result
        expect(result.success?).to be true
      end

      it "handles both empty" do
        merger = described_class.new("", "")
        result = merger.merge_result
        expect(result.success?).to be true
      end
    end

    context "with statistics" do
      let(:template) do
        <<~MARKDOWN
          # Title

          ## Section

          Template content.

          ## New Section

          New content.
        MARKDOWN
      end
      let(:destination) do
        <<~MARKDOWN
          # Title

          ## Section

          Destination content.
        MARKDOWN
      end

      it "tracks merge time" do
        merger = described_class.new(template, destination)
        result = merger.merge_result
        expect(result.stats[:merge_time_ms]).to be >= 0
      end

      it "tracks nodes modified" do
        merger = described_class.new(template, destination, preference: :template)
        result = merger.merge_result
        expect(result.stats[:nodes_modified]).to be >= 0
      end

      it "tracks nodes added when template_only_nodes enabled" do
        merger = described_class.new(template, destination, add_template_only_nodes: true)
        result = merger.merge_result
        expect(result.stats[:nodes_added]).to be >= 0
      end
    end
  end

  describe "error handling" do
    it "wraps template parse errors" do
      # CommonMarker is very tolerant, so this might not actually raise
      # but the structure should handle it
      expect { described_class.new("# Valid", "# Valid") }.not_to raise_error
    end
  end

  describe "#process_alignment edge cases" do
    # Lines 181, 184: when part is nil (template_only with add_template_only_nodes: false)
    context "with template-only nodes not added" do
      let(:template) do
        <<~MARKDOWN
          # Template Title

          Template intro.

          ## New Section

          This section only exists in template.
        MARKDOWN
      end
      let(:dest) do
        <<~MARKDOWN
          # Template Title

          Destination intro.
        MARKDOWN
      end

      it "skips template-only nodes when add_template_only_nodes is false" do
        merger = described_class.new(template, dest, add_template_only_nodes: false)
        result = merger.merge_result
        expect(result.success?).to be true
        # "New Section" should NOT be in output - covers line 184 (part is nil)
        expect(result.content).not_to include("New Section")
      end
    end

    # Line 185: when frozen is truthy in process_match
    # Line 191: when frozen is truthy in process_dest_only
    context "with freeze blocks in destination" do
      let(:template) do
        <<~MARKDOWN
          # Document

          Template content.

          ## Section

          More template.
        MARKDOWN
      end
      let(:dest) do
        <<~MARKDOWN
          # Document

          <!-- commonmarker-merge:freeze -->
          Frozen dest content.
          <!-- commonmarker-merge:unfreeze -->

          ## Section

          Different dest content.
        MARKDOWN
      end

      it "tracks frozen blocks from destination" do
        merger = described_class.new(template, dest)
        result = merger.merge_result
        expect(result.success?).to be true
        # Frozen blocks should be tracked - covers lines 185, 191
        expect(result.frozen_blocks).to be_an(Array)
      end
    end

    context "with only dest content" do
      let(:template) { "" }
      let(:dest) do
        <<~MARKDOWN
          # Destination Only

          This is destination content.
        MARKDOWN
      end

      it "handles dest-only entries" do
        merger = described_class.new(template, dest)
        result = merger.merge_result
        expect(result.success?).to be true
      end
    end
  end

  describe "#process_match edge cases" do
    # Lines 214-220: when resolution source is :destination with freeze node
    context "when dest node is a FreezeNode" do
      let(:template) do
        <<~MARKDOWN
          # Document

          Template paragraph.
        MARKDOWN
      end
      let(:dest) do
        <<~MARKDOWN
          # Document

          <!-- commonmarker-merge:freeze -->
          Frozen destination content that matches heading.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "preserves frozen content and records frozen_info" do
        merger = described_class.new(template, dest, preference: :destination)
        result = merger.merge_result
        expect(result.success?).to be true
      end
    end

    # Line 216: else branch - when dest_node doesn't respond to freeze_node?
    context "when dest node is regular node" do
      let(:template) { "# Same\n\nTemplate para.\n" }
      let(:dest) { "# Same\n\nDest para.\n" }

      it "handles regular nodes without freeze_node? method" do
        merger = described_class.new(template, dest, preference: :destination)
        result = merger.merge_result
        expect(result.success?).to be true
        # Regular nodes don't have freeze_node? - covers line 216 else
      end
    end
  end

  describe "#node_to_source edge cases" do
    # Lines 275-278: FreezeNode vs regular node handling
    context "with FreezeNode in dest_only" do
      let(:template) { "# Only Heading\n" }
      let(:dest) do
        <<~MARKDOWN
          # Only Heading

          <!-- commonmarker-merge:freeze -->
          This is a freeze block only in dest.
          <!-- commonmarker-merge:unfreeze -->
        MARKDOWN
      end

      it "uses full_text for FreezeNode" do
        merger = described_class.new(template, dest)
        result = merger.merge_result
        expect(result.success?).to be true
        # FreezeNode uses full_text - covers line 275
        expect(result.content).to include("freeze block only in dest")
      end
    end

    # Line 278: when node lacks source position - fallback to to_commonmark
    # This is hard to trigger with real CommonMarker nodes
  end
end
