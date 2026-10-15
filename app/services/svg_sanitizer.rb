class SvgSanitizer
  class Invalid < StandardError; end
  ELEMENTS = %w[g path circle ellipse rect line polyline polygon].freeze
  NUMERIC = %w[x y x1 x2 y1 y2 cx cy r rx ry width height stroke-width stroke-miterlimit opacity fill-opacity stroke-opacity stroke-dashoffset].freeze
  COLORS = %w[none transparent black white red blue green yellow orange purple pink brown gray grey navy gold coral teal beige ivory].freeze

  def self.call(source)
    raise Invalid, "Drawing was empty or too large" if source.blank? || source.bytesize > 200_000
    raise Invalid, "Unsupported XML declaration" if source.match?(/<!DOCTYPE|<!ENTITY/i)

    xml = source.strip.sub(/\A```(?:svg|xml)?\s*/i, "").sub(/\s*```\z/, "")
    document = Nokogiri::XML(xml) { |config| config.strict.nonet }
    root = document.root
    raise Invalid, "Drawing must be an SVG" unless root&.name == "svg"

    clean = Nokogiri::XML::Document.new
    output = Nokogiri::XML::Node.new("svg", clean)
    clean.root = output
    output["xmlns"] = "http://www.w3.org/2000/svg"
    viewport = root["viewBox"].to_s
    numbers = viewport.split(/[\s,]+/).map { |value| Float(value, exception: false) }
    raise Invalid, "Drawing needs a valid viewBox" unless numbers.size == 4 && numbers.all? { |n| n&.finite? } && numbers[2..].all?(&:positive?)
    output["viewBox"] = viewport
    copy_attributes(root, output)
    copy_children(root, output, clean)
    raise Invalid, "Drawing has no shapes" unless output.xpath(".//*[not(self::g)]").any?

    output.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  rescue Nokogiri::XML::SyntaxError
    raise Invalid, "Drawing was incomplete"
  end

  def self.copy_children(source, target, document)
    source.element_children.each do |node|
      next unless ELEMENTS.include?(node.name) && [ nil, "http://www.w3.org/2000/svg" ].include?(node.namespace&.href)
      child = Nokogiri::XML::Node.new(node.name, document)
      copy_attributes(node, child)
      target.add_child(child)
      copy_children(node, child, document) if node.name == "g"
    end
  end

  def self.copy_attributes(source, target)
    source.attribute_nodes.each do |attr|
      next if attr.namespace
      name, value = attr.name, attr.value
      next if value.length > 30_000
      safe = case name
      when *NUMERIC then value.match?(/\A-?[\d.]+(?:e[+-]?\d+)?%?\z/i)
      when "fill", "stroke" then COLORS.include?(value) || value.match?(/\A#[0-9a-f]{3,8}\z/i) || value.match?(/\Argb[a]?\([\d.,%\s]+\)\z/i)
      when "d" then value.match?(/\A[MmZzLlHhVvCcSsQqTtAa0-9eE.,+\s-]+\z/)
      when "points", "stroke-dasharray" then value.match?(/\A[\d.eE,+\s-]+\z/)
      when "transform" then value.match?(/\A(?:(?:translate|scale|rotate|matrix|skewX|skewY)\([\d.eE,+\s-]+\)\s*)+\z/)
      when "stroke-linecap" then %w[round butt square].include?(value)
      when "stroke-linejoin" then %w[round miter bevel].include?(value)
      when "fill-rule", "clip-rule" then %w[nonzero evenodd].include?(value)
      else false
      end
      target[name] = value if safe
    end
  end
end
