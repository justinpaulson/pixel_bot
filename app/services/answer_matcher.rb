class AnswerMatcher
  def self.normalize(text)
    ActiveSupport::Inflector.transliterate(text.to_s).downcase.gsub("&", "and").gsub(/\b(the|a|an)\b/, "").gsub(/[^a-z0-9]/, "")
  end

  def self.match?(guess, answers)
    value = normalize(guess)
    return false if value.empty? || value.length > 120

    answers.any? do |answer|
      target = normalize(answer)
      next true if value == target
      next false if target.length < 6

      tolerance = target.length >= 12 ? 2 : 1
      next false if (value.length - target.length).abs > tolerance

      distance(value, target) <= tolerance
    end
  end

  def self.distance(left, right)
    previous = (0..right.length).to_a
    left.each_char.with_index(1) do |a, i|
      current = [ i ]
      right.each_char.with_index(1) do |b, j|
        current[j] = [ current[j - 1] + 1, previous[j] + 1, previous[j - 1] + (a == b ? 0 : 1) ].min
      end
      previous = current
    end
    previous.last
  end
end
