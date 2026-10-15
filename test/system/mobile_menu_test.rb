require "application_system_test_case"

class MobileMenuTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome do |options|
    options.add_emulation(device_metrics: { width: 402, height: 874, pixelRatio: 3, mobile: true, touch: true })
  end

  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "phone menu fits and opens accessible help and player sheets" do
    visit root_path
    assert_selector ".mobile-menu", text: "THE AI DRAWING GAME"
    assert_no_selector ".game-menu"
    assert_no_text "Pixel draws. You guess."
    assert page.evaluate_script("document.documentElement.scrollHeight <= innerHeight")
    assert page.evaluate_script("document.querySelector('.menu-home-links').getBoundingClientRect().bottom < innerHeight - 20")

    find("button[aria-label='How to play']").click
    assert_selector "dialog[open]", text: "See it. Guess it."
    click_button "Got it"
    assert_no_selector "dialog[open]"
    assert_equal "How to play", page.evaluate_script("document.activeElement.getAttribute('aria-label')")

    find("button[aria-label='Player settings']").click
    fill_in "Nickname", with: "Sketch Friend"
    assert_equal "16px", page.evaluate_script("getComputedStyle(document.querySelector('#mobile-nickname')).fontSize")
    click_button "Done"
    page.refresh
    find("button[aria-label='Player settings']").click
    assert_field "Nickname", with: "Sketch Friend"
  end

  test "saved menu choices create the requested room through the website session" do
    visit root_path
    assert_selector ".mobile-menu"
    find("button[aria-label='Player settings']").click
    fill_in "Nickname", with: "Web Host"
    click_button "Done"
    choose "Friends", allow_label_click: true
    select "Songs", from: "mobile-category"
    choose "mobile-rounds-10", allow_label_click: true
    choose "mobile-artist-luna", allow_label_click: true
    assert_selector ".menu-preview", text: "Luna’s sketchbook"
    assert_selector ".menu-preview img[alt='Luna drawing Jurassic Park']"
    assert_no_selector ".menu-preview img[alt='Astra drawing Jurassic Park']"
    page.refresh
    assert_checked_field "Friends", visible: :all
    assert_selector "#mobile-category option:checked", text: "Songs"
    assert_checked_field "mobile-rounds-10", visible: :all
    assert_checked_field "mobile-artist-luna", visible: :all
    click_button "Create room", exact: true
    assert_current_path %r{\A/games/[0-9a-f-]+\z}
    game = Game.find(URI.parse(current_url).path.split("/").last)
    assert_equal [ "party", "music", 10, "gpt-6-luna", "Web Host" ],
      [ game.mode, game.category, game.round_limit, game.drawing_model, game.created_by.name ]
    assert game.created_by.guest?
    assert_equal 1, game.players.count
  end

  test "join sheet rejects unrelated links and joins a real invite with a nickname" do
    game = build_game(mode: "party")
    visit root_path
    click_button "Join room", exact: true
    fill_in "Invite link", with: "https://example.com/games/#{game.id}"
    fill_in "Nickname", with: "Web Guest"
    click_button "Join", exact: true
    assert_selector "[role='alert']", text: "Paste a Pixel invite link."
    assert_current_path root_path
    assert_equal 1, game.players.count

    fill_in "Invite link", with: "https://pixel.justinpaulson.com/games/#{game.id}"
    click_button "Join", exact: true
    assert_current_path game_path(game)
    assert_equal 2, game.players.count
    assert_equal "Web Guest", game.players.order(:created_at, :id).last.user.name
  end
end
