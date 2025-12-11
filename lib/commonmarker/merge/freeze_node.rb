# frozen_string_literal: true

module Commonmarker
  module Merge
    # Represents a frozen block of Markdown content that should be preserved during merges.
    #
    # Inherits from Markdown::Merge::FreezeNode which provides the generic
    # freeze block handling.
    #
    # Freeze blocks are marked with HTML comments:
    #   <!-- commonmarker-merge:freeze -->
    #   ... frozen content ...
    #   <!-- commonmarker-merge:unfreeze -->
    #
    # @example Basic freeze block
    #   <!-- commonmarker-merge:freeze -->
    #   ## Custom Section
    #   This content will not be modified by merge operations.
    #   <!-- commonmarker-merge:unfreeze -->
    #
    # @example Freeze block with reason
    #   <!-- commonmarker-merge:freeze Manual TOC -->
    #   ## Table of Contents
    #   - [Introduction](#introduction)
    #   - [Usage](#usage)
    #   <!-- commonmarker-merge:unfreeze -->
    #
    # @see Markdown::Merge::FreezeNode
    class FreezeNode < Markdown::Merge::FreezeNode
    end
  end
end
