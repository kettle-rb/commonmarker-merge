# frozen_string_literal: true

require "spec_helper"

RSpec.describe Commonmarker::Merge::Version do
  it_behaves_like "a Version module", described_class
end
