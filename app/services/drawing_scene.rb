class DrawingScene
  # Send geometry, never markup, to the animated canvas. The same sanitizer
  # protects both this representation and the isolated, static SVG image.
  def self.call(source)
    root = Nokogiri::XML(SvgSanitizer.call(source)) { |config| config.strict.nonet }.root
    { view_box: root["viewBox"], art: serialize(root, tag: "g") }
  end

  def self.serialize(node, tag: node.name)
    {
      tag: tag,
      attributes: node.attribute_nodes.reject { |attr| attr.name == "viewBox" || attr.namespace }.to_h { |attr| [ attr.name, attr.value ] },
      children: node.element_children.map { |child| serialize(child) }
    }
  end
  private_class_method :serialize
end
