require "./spec_helper"

describe ImportMap::Manager do
  it "merges base and namespace pins (base only call)" do
    mgr = ImportMap::Manager.new
    mgr.pin("stimulus", "/js/stimulus.js")
    mgr.namespace("admin") do
      pin("sort_controller", "/js/admin/sort_controller.js")
    end

    mgr.json.should eq({"imports" => {"stimulus" => "/js/stimulus.js"}}.to_json)
  end

  it "merges base and namespace pins" do
    mgr = ImportMap::Manager.new
    mgr.pin("stimulus", "/js/stimulus.js")
    mgr.namespace("admin") do
      pin("sort_controller", "/js/admin/sort_controller.js")
    end

    mgr.json("admin").should eq({"imports" => {"stimulus" => "/js/stimulus.js", "sort_controller" => "/js/admin/sort_controller.js"}}.to_json)
  end

  it "allows namespace pins to override base pins" do
    mgr = ImportMap::Manager.new
    mgr.pin("application", "/js/application.js")
    mgr.namespace("admin") do
      pin("application", "/js/admin/application.js")
    end

    mgr.json("admin").should eq({"imports" => {"application" => "/js/admin/application.js"}}.to_json)
  end

  it "raises on unknown namespace" do
    mgr = ImportMap::Manager.new

    expect_raises ImportMap::NamespaceError do
      mgr.json("unknown")
    end
  end

  it "resolves URLs via custom resolver and caches" do
    mgr = ImportMap::Manager.new
    mgr.pin("stimulus", "/js/stimulus.js")
    mgr.pin("turbo", "/js/turbo.js")

    resolver = ->(path : String) { "/assets#{path}?v=abc" }
    mgr.resolver = resolver

    mgr.json.should eq({"imports" => {"stimulus" => "/assets/js/stimulus.js?v=abc", "turbo" => "/assets/js/turbo.js?v=abc"}}.to_json)
    mgr.preloads.empty?.should be_false
  end

  it "returns a copy of preloads so callers cannot mutate the cache" do
    mgr = ImportMap::Manager.new
    mgr.pin("stimulus", "/js/stimulus.js")

    leaked = mgr.preloads
    leaked << "/js/injected.js"

    mgr.preloads.should eq(["/js/stimulus.js"])
    mgr.preloads.should_not be(leaked)
  end

  it "return an empty preloads array when all pins have preload=false" do
    mgr = ImportMap::Manager.new
    mgr.pin("stimulus", "/js/stimulus.js", preload: false)
    mgr.pin("turbo", "/js/turbo.js", preload: false)

    mgr.namespace("admin") do
      pin("sort_controller", "/js/admin/sort_controller.js", preload: false)
    end

    mgr.preloads.empty?.should be_true
    mgr.preloads("admin").empty?.should be_true
  end

  it "expands pin_all_from directives inside namespaces" do
    with_tmpdir do |dir|
      controllers_dir = File.join(dir, "controllers")
      FileUtils.mkdir_p(controllers_dir)
      File.write(File.join(controllers_dir, "menu_controller.js"), "// menu")

      mgr = ImportMap::Manager.new
      mgr.namespace("admin") do
        pin_all_from(controllers_dir, under: "controllers", to: "controllers")
      end

      mgr.json("admin").should eq({
        "imports" => {
          "controllers/menu_controller" => "controllers/menu_controller.js",
        },
      }.to_json)
    end
  end
end
