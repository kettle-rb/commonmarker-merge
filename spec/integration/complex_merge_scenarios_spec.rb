# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Complex Merge Scenarios" do
  context "with thematic breaks" do
    let(:template) do
      <<~MARKDOWN
        # Document

        First section.

        ---

        Second section.
      MARKDOWN
    end

    let(:dest) do
      <<~MARKDOWN
        # Document

        Modified first section.

        ---

        Modified second section.
      MARKDOWN
    end

    it "handles thematic breaks correctly" do
      merger = Commonmarker::Merge::SmartMerger.new(template, dest)
      result = merger.merge_result
      expect(result.success?).to be true
    end
  end

  context "with HTML blocks" do
    let(:template) do
      <<~MARKDOWN
        # Document

        <div class="custom">
          Custom HTML content
        </div>

        Normal paragraph.
      MARKDOWN
    end

    let(:dest) do
      <<~MARKDOWN
        # Document

        <div class="custom">
          Modified HTML content
        </div>

        Different paragraph.
      MARKDOWN
    end

    it "handles HTML blocks" do
      merger = Commonmarker::Merge::SmartMerger.new(template, dest)
      result = merger.merge_result
      expect(result.success?).to be true
    end
  end

  context "with block quotes" do
    let(:template) do
      <<~MARKDOWN
        # Document

        > This is a quote
        > with multiple lines.

        Normal paragraph.
      MARKDOWN
    end

    let(:dest) do
      <<~MARKDOWN
        # Document

        > Different quote content
        > also multiple lines.

        Different paragraph.
      MARKDOWN
    end

    it "handles block quotes" do
      merger = Commonmarker::Merge::SmartMerger.new(template, dest)
      result = merger.merge_result
      expect(result.success?).to be true
    end
  end

  context "with code blocks having different fence info" do
    let(:template) do
      <<~MARKDOWN
        # Code Examples

        ```ruby
        def hello
          puts "world"
        end
        ```

        ```javascript
        console.log("hello");
        ```
      MARKDOWN
    end

    let(:dest) do
      <<~MARKDOWN
        # Code Examples

        ```ruby
        def goodbye
          puts "world"
        end
        ```

        ```javascript
        console.log("goodbye");
        ```
      MARKDOWN
    end

    it "handles multiple code blocks with different languages" do
      merger = Commonmarker::Merge::SmartMerger.new(template, dest)
      result = merger.merge_result
      expect(result.success?).to be true
    end
  end

  context "with deeply nested content" do
    let(:template) do
      <<~MARKDOWN
        # Main

        - Item 1
          - Nested 1.1
          - Nested 1.2
        - Item 2
      MARKDOWN
    end

    let(:dest) do
      <<~MARKDOWN
        # Main

        - Item 1
          - Modified 1.1
          - Nested 1.2
        - Item 2
        - Item 3
      MARKDOWN
    end

    it "handles nested lists" do
      merger = Commonmarker::Merge::SmartMerger.new(template, dest)
      result = merger.merge_result
      expect(result.success?).to be true
    end
  end
end
