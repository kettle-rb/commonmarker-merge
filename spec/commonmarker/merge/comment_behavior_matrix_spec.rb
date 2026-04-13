# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe "commonmarker comment behavior matrix", :commonmarker_merge do
  extend Ast::Merge::RSpec::CommentBehaviorMatrixAdapters

  it_behaves_like "Ast::Merge::CommentBehaviorMatrix" do
    markdown_link_definition_comment_matrix_adapter(
      analysis_class: Commonmarker::Merge::FileAnalysis,
      merger_class: Commonmarker::Merge::SmartMerger,
    )
  end
end
