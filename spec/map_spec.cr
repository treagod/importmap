require "./spec_helper"

describe ImportMap::Map do
  it "pins entries and outputs valid JSON" do
    map = ImportMap::Map.new
    map.pin("stimulus", "/js/stimulus.js", preload: false)
    map.pin("turbo", "/js/turbo.js")
    json = map.to_json_string
    json.should eq({"imports" => {"stimulus" => "/js/stimulus.js", "turbo" => "/js/turbo.js"}}.to_json)
  end

  it "pins entries without starting slash and outputs valid JSON" do
    map = ImportMap::Map.new
    map.pin("stimulus", "js/stimulus.js", preload: false)
    map.pin("turbo", "js/turbo.js")
    json = map.to_json_string
    json.should eq({"imports" => {"stimulus" => "js/stimulus.js", "turbo" => "js/turbo.js"}}.to_json)
  end

  it "accepts the `to:` keyword for the url" do
    map = ImportMap::Map.new
    map.pin("stimulus", to: "/js/stimulus.js")
    json = map.to_json_string
    json.should eq({"imports" => {"stimulus" => "/js/stimulus.js"}}.to_json)
  end

  it "detects duplicate pins" do
    map = ImportMap::Map.new
    map.pin("stimulus", "/js/stimulus.js")

    expect_raises ImportMap::DuplicatePinError do
      map.pin("stimulus", "/js/another_stimulus.js")
    end
  end

  it "supports override" do
    map = ImportMap::Map.new
    map.pin("stimulus", "/js/stimulus.js")
    map.pin("stimulus", "/js/another_stimulus.js", override: true)
    json = map.to_json_string
    json.should eq({"imports" => {"stimulus" => "/js/another_stimulus.js"}}.to_json)
  end

  it "applies resolver" do
    map = ImportMap::Map.new
    map.pin("stimulus", "/js/stimulus.js")
    map.pin("turbo", "/js/turbo.js")
    resolver = ->(path : String) { "/assets#{path}?v=abc" }
    json = map.to_json_string(resolver)
    json.should eq({"imports" => {"stimulus" => "/assets/js/stimulus.js?v=abc", "turbo" => "/assets/js/turbo.js?v=abc"}}.to_json)
  end

  it "pins all modules from a directory with namespace and destination overrides" do
    with_tmpdir do |dir|
      controllers_dir = File.join(dir, "controllers")
      FileUtils.mkdir_p(File.join(controllers_dir, "admin"))

      File.write(File.join(controllers_dir, "admin", "user_controller.js"), "// admin controller")
      File.write(File.join(controllers_dir, "hello_controller.js"), "// hello controller")
      File.write(File.join(controllers_dir, ".keep"), "")

      map = ImportMap::Map.new
      map.pin_all_from(controllers_dir, under: "controllers", to: "controllers")

      json = map.to_json_string
      json.should eq({
        "imports" => {
          "controllers/admin/user_controller" => "controllers/admin/user_controller.js",
          "controllers/hello_controller"      => "controllers/hello_controller.js",
        },
      }.to_json)
    end
  end

  it "allows pin_all_from without namespace and respects preload flag" do
    with_tmpdir do |dir|
      services_dir = File.join(dir, "services")
      FileUtils.mkdir_p(services_dir)

      File.write(File.join(services_dir, "logger.mjs"), "// logger")

      map = ImportMap::Map.new
      map.pin_all_from(services_dir, preload: false)

      map.preload_urls.should be_empty

      json = map.to_json_string
      json.should eq({
        "imports" => {
          "logger" => "logger.mjs",
        },
      }.to_json)
    end
  end

  it "merged allows other map to override duplicates" do
    base = ImportMap::Map.new
    base.pin("stimulus", "/js/stimulus.js")

    admin = ImportMap::Map.new
    admin.pin("sort_controller", "/js/admin/sort_controller.js")
    admin.pin("stimulus", "/js/admin/stimulus.js")

    merged = base.merge(admin)
    merged.entries["stimulus"].url.should eq("/js/admin/stimulus.js")
    merged.entries.has_key?("sort_controller").should be_true
  end
end
