require "test_helper"

class DrawingSceneTest < ActiveSupport::TestCase
  test "scene preserves nested shapes, inherited presentation, and transforms without markup" do
    scene = DrawingScene.call(<<~SVG)
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="10 20 512 512" fill="none" stroke="#123456">
        <g transform="translate(5 8) rotate(20)" opacity="0.5"><path d="M0 0L10 10" stroke-dasharray="3 4"/><circle cx="5" cy="8" r="4" fill="#abcdef"/></g>
      </svg>
    SVG
    assert_equal "10 20 512 512", scene[:view_box]
    assert_equal "g", scene[:art][:tag]
    assert_equal({ "fill" => "none", "stroke" => "#123456" }, scene[:art][:attributes])
    group = scene[:art][:children].sole
    assert_equal "translate(5 8) rotate(20)", group[:attributes]["transform"]
    assert_equal "0.5", group[:attributes]["opacity"]
    assert_equal %w[path circle], group[:children].pluck(:tag)
    assert_equal "3 4", group[:children].first[:attributes]["stroke-dasharray"]
    assert_equal "#abcdef", group[:children].last[:attributes]["fill"]
  end

  test "scene strips executable content and secrets through the delivery sanitizer" do
    scene = DrawingScene.call(<<~SVG)
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" onload="secret()">
        <title>Secret answer</title><script>secret()</script><foreignObject><p>secret</p></foreignObject>
        <image href="https://example.com/secret"/><use href="#secret"/>
        <g id="secret" style="fill:url(https://example.com/secret)"><path d="M0 0L10 10" fill="url(#secret)" onclick="secret()"/></g>
      </svg>
    SVG
    assert_not_includes scene.to_json, "secret"
    assert_not_includes scene.to_json, "Secret"
    assert_equal({ "d" => "M0 0L10 10" }, scene[:art][:children].sole[:children].sole[:attributes])
    assert_raises(SvgSanitizer::Invalid) { DrawingScene.call('<svg viewBox="0 0 512 512"><path') }
  end
end
