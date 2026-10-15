require "test_helper"

class AnswerMatcherTest < ActiveSupport::TestCase
  test "ignores accents punctuation articles and case" do
    assert AnswerMatcher.match?("beyonce", [ "Beyoncé" ])
    assert AnswerMatcher.match?("the  LORD of the rings!", [ "Lord of the Rings" ])
    assert AnswerMatcher.match?("spider man", [ "Spider-Man" ])
    assert AnswerMatcher.match?("ET", [ "E.T." ])
  end

  test "allows a small typo in long names but not arbitrary short guesses" do
    assert AnswerMatcher.match?("Jurasic Park", [ "Jurassic Park" ])
    assert AnswerMatcher.match?("LOTR", [ "The Lord of the Rings", "LOTR" ])
    assert_not AnswerMatcher.match?("cat", [ "Bat" ])
    assert_not AnswerMatcher.match?("up", [ "Cup" ])
    assert_not AnswerMatcher.match?("", [ "" ])
    assert_not AnswerMatcher.match?("park", [ "Jurassic Park" ])
    assert_not AnswerMatcher.match?("a" * 121, [ "a" * 121 ])
  end
end
