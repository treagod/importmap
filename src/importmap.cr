require "json"
require "./**"

module ImportMap
  VERSION = "0.1.0"

  def self.draw(&)
    with ImportMap::Manager.instance yield
  end

  def self.resolver=(resolver : Proc(String, String))
    ImportMap::Manager.instance.resolver = resolver
  end

  def self.tag(ns : String? = nil, entrypoint : String? = nil)
    m = Manager.instance

    json = m.json(ns)
    preloads = m.preloads(ns)

    String.build do |io|
      data = ns ? %( data-namespace="#{html_attr_escape(ns)}") : ""

      io << %(<script type="importmap"#{data}>#{script_json_escape(json)}</script>\n)

      preloads.each do |url|
        io << %(<link rel="modulepreload" href="#{html_attr_escape(url)}">\n)
      end

      if entrypoint
        safe_entrypoint = script_json_escape(js_string_escape(entrypoint))
        io << %(<script type="module">import "#{safe_entrypoint}"</script>\n)
      end
    end
  end

  # Escapes a value for use inside a double-quoted HTML attribute.
  private def self.html_attr_escape(value : String) : String
    value
      .gsub('&', "&amp;")
      .gsub('"', "&quot;")
      .gsub('<', "&lt;")
      .gsub('>', "&gt;")
  end

  # Escapes `<` so the value cannot terminate or open a tag while sitting inside
  # a `<script>` raw-text element. `<` is a valid escape in both JSON and JS
  # string literals, so it round-trips to `<` for the importmap/JS parser while
  # neutralizing `</script`, `<script` and `<!--` in any casing.
  private def self.script_json_escape(value : String) : String
    value.gsub('<', "\\u003C")
  end

  # Escapes a value for use as the body of a double-quoted JS string literal.
  private def self.js_string_escape(value : String) : String
    value.to_json[1...-1]
  end
end
