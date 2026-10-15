require "test_helper"

class SvgSanitizerTest < ActiveSupport::TestCase
  test "strips executable markup external references and answer metadata" do
    source = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" onload="alert(1)" aria-label="Secret Answer">
        <title>Secret Answer</title><!-- Secret Answer --><desc>Secret Answer</desc>
        <script>alert(1)</script><foreignObject><div>Secret Answer</div></foreignObject>
        <image href="https://example.com/tracker"/><use href="#secret"/><style>path{fill:red}</style>
        <g id="SecretAnswer" class="secret" data-answer="Secret Answer"><path d="M10 10L40 50Z" fill="#123456" stroke="url(https://example.com)" onclick="alert(1)"/></g>
      </svg>
    SVG
    clean = SvgSanitizer.call(source)
    %w[Secret Answer script foreignObject href onload onclick url style class data-answer].each { |word| assert_not_includes clean, word }
    assert_includes clean, 'fill="#123456"'
    assert_equal clean, SvgSanitizer.call(clean)
  end

  test "rejects malformed empty excessive or entity based drawings" do
    [ "<svg>", "", "x" * 200_001, '<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///etc/passwd">]><svg/>', '<svg viewBox="0 0 512 512"><text>Answer</text></svg>', '<svg viewBox="0 0 0 0"><path d="M1 1"/></svg>' ].each do |source|
      assert_raises(SvgSanitizer::Invalid) { SvgSanitizer.call(source) }
    end
  end

  test "accepts fenced SVG and preserves geometry and transforms" do
    clean = SvgSanitizer.call("```svg\n<svg viewBox=\"0 0 512 512\"><g transform=\"translate(1 2) rotate(30)\"><circle r=\"20\" fill=\"red\"/></g></svg>\n```")
    assert_includes clean, 'transform="translate(1 2) rotate(30)"'
    assert_includes clean, 'r="20"'
  end
end
