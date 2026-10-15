require "application_system_test_case"

class GameInputTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome do |options|
    options.add_emulation(device_metrics: { width: 390, height: 844, pixelRatio: 3, mobile: true, touch: true })
  end

  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "mobile guesses preserve focus and layout across repeated submissions and round changes" do
    game = build_game
    ready_round(game)

    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in / create account"
    assert_current_path root_path
    visit game_path(game)
    assert_button "Sign out"
    assert_selector "#guess:not([disabled])"
    assert_not page.evaluate_script("document.activeElement.id === 'guess'")
    assert_equal "16px", page.evaluate_script("getComputedStyle(document.querySelector('#guess')).fontSize")

    input = find("#guess")
    input.set("Definitely not the answer")
    before = layout
    3.times do |attempt|
      input.set("Wrong guess #{attempt}")
      if attempt == 1
        input.send_keys(:enter)
      else
        tap_guess
      end
      assert_selector ".guess-feedback", text: "Not quite."
      assert_field "Your guess", with: ""
      assert page.evaluate_script("document.activeElement.id === 'guess'")
      assert_equal before, layout
    end

    # A cached next round can become playable immediately after a reveal.
    ready_round(game, number: 2)
    game.update!(active_round_number: 2)
    assert_selector ".round-label", text: "Round 2 / 3"
    assert_equal before, layout
    assert_equal "", find(".guess-feedback", visible: :all).text
    page.save_screenshot(Rails.root.join("tmp/mobile-guess-layout.png"))
  end

  private

  def layout
    page.evaluate_script(<<~JS)
      ({ scroll: window.scrollY, scale: window.visualViewport.scale,
         input: document.querySelector('#guess').getBoundingClientRect().top,
         scores: document.querySelector('.score-card').getBoundingClientRect().top })
    JS
  end

  def tap_guess
    point = page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector('[data-game-target="guessButton"]').getBoundingClientRect();
        return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
      })()
    JS
    page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [ point ])
    page.driver.browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end
end
