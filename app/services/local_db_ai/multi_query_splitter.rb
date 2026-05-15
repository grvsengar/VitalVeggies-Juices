module LocalDbAi
  class MultiQuerySplitter
    # Connectors that signal a compound question
    SPLIT_PATTERN = /\s+(?:and\s+also|and|&|\+|also|along\s+with|as\s+well\s+as|plus|with|,\s*(?:and\s+)?)\s*/i

    # Returns an array of 2+ sub-questions, or nil if single intent
    def self.split(question)
      parts = question.strip.split(SPLIT_PATTERN).map(&:strip).reject(&:blank?)
      return nil if parts.length < 2

      # Reject splits that look like a single coherent phrase
      # e.g. "orders by customer gaurav" — "by" is not a split point
      # Only split if each part looks independently queryable (has 2+ words)
      valid = parts.all? { |p| p.split.length >= 2 }
      return nil unless valid

      parts
    end
  end
end
