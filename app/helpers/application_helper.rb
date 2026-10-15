module ApplicationHelper
  def pixel_tip_jar
    # The gem's inline styles and event handlers conflict with our CSP. Keep its
    # jar artwork and direct payment link; application.css handles presentation.
    fragment = Nokogiri::HTML5.fragment(tip_jar(
      payment_link: "https://buy.stripe.com/9B600i4VY3Be3CT4AOfrW00",
      message: "Tip jar",
      class: "pixel-tip-jar"
    ))
    fragment.css("style").remove
    fragment.css("*").each do |node|
      node.attribute_nodes.each do |attribute|
        node.remove_attribute(attribute.name) if attribute.name == "style" || attribute.name.start_with?("on")
      end
    end
    fragment.at_css("a")["aria-label"] = "Tip jar for Pixel (opens Stripe in a new tab)"
    fragment.at_css("svg")["aria-hidden"] = "true"
    fragment.at_css("svg")["focusable"] = "false"
    fragment.to_html.html_safe
  end
end
