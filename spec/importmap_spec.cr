require "./spec_helper"

ImportMap.draw do
  pin "stimulus", "/js/stimulus.js"

  namespace "admin" do
    pin "sort_controller", "/js/admin/sort_controller.js", preload: false
  end
end

describe ImportMap do
  it "populates manager via DSL" do
    ImportMap::Manager.instance.json("admin").should eq(
      {"imports" => {"stimulus" => "/js/stimulus.js", "sort_controller" => "/js/admin/sort_controller.js"}}.to_json
    )
  end

  it "renders correct HTML tag block" do
    html = ImportMap.tag("admin", "entrypoint")
    html.includes?(%(<link rel="modulepreload" href="/js/stimulus.js">)).should be_true
    html.includes?(%(<link rel="modulepreload" href="/js/admin/sort_controller.js">)).should be_false
    html.includes?(%(<script type="importmap" data-namespace="admin">)).should be_true
    html.includes?(%(<script type="module">import "entrypoint"</script>)).should be_true
    html.includes?(%(<script type="importmap">)).should be_false
  end

  it "resolves paths correctly when setting a custom resolver" do
    ImportMap.resolver = ->(path : String) { "/assets#{path}?v=abc" }
    html = ImportMap.tag("admin", "entrypoint")
    html.includes?(%(<link rel="modulepreload" href="/assets/js/stimulus.js?v=abc">)).should be_true

    ImportMap.resolver = ->(path : String) { path }
  end
end

EVIL_URL   = %(/js/x.js"></script><script>alert(1)</script>)
EVIL_NS    = %(evil" onx="1)
EVIL_ENTRY = %(</script><img src=x onerror=alert(1)>)

ImportMap.draw do
  namespace EVIL_NS do
    pin "evil", to: EVIL_URL
  end
end

describe "ImportMap escaping" do
  describe "html_attr_escape" do
    it "escapes &, \", < and >" do
      ImportMap.html_attr_escape!(%(a&b"c<d>e)).should eq(%(a&amp;b&quot;c&lt;d&gt;e))
    end
  end

  describe "script_json_escape" do
    it "escapes < so the value cannot terminate a <script> element" do
      escaped = ImportMap.script_json_escape!("</script>")
      escaped.includes?('<').should be_false
      escaped.should eq("#{92.chr}u003C/script>")
    end
  end

  describe "js_string_escape" do
    it "escapes quotes and control characters" do
      ImportMap.js_string_escape!(%(a"b)).should eq(%q(a\"b))
      ImportMap.js_string_escape!("a\nb").should eq(%q(a\nb))
    end
  end

  describe "ImportMap.tag" do
    it "escapes pin URLs, namespace and entrypoint so injected markup cannot break out" do
      html = ImportMap.tag(EVIL_NS, EVIL_ENTRY)

      # No raw breakout from any injected value.
      html.includes?(EVIL_URL).should be_false
      html.includes?(%(<script>alert(1)</script>)).should be_false
      html.includes?(%(<img src=x onerror=alert(1)>)).should be_false

      # Values survive, but only in escaped form.
      html.includes?(%(data-namespace="evil&quot; onx=&quot;1")).should be_true
      html.includes?(%(href="/js/x.js&quot;&gt;&lt;/script&gt;)).should be_true
      html.includes?("#{92.chr}u003C/script>").should be_true
    end
  end
end

# Must stay the LAST example in this file: it wipes the global singleton, and
# Crystal runs examples in definition order.
describe "ImportMap::Manager.reset!" do
  it "replaces the singleton with a fresh, empty instance" do
    before = ImportMap::Manager.instance
    before.pin("reset_probe", to: "/probe.js")

    fresh = ImportMap::Manager.reset!

    fresh.should be(ImportMap::Manager.instance)
    fresh.should_not be(before)
    fresh.json.should eq(%({"imports":{}}))
  end
end
