require "spec"
require "file_utils"
require "random/secure"
require "../src/importmap"

module ImportMap
  class Map
    def entries
      @entries
    end
  end

  # Public delegators so the private escape helpers can be unit-tested directly.
  def self.html_attr_escape!(value : String) : String
    html_attr_escape(value)
  end

  def self.script_json_escape!(value : String) : String
    script_json_escape(value)
  end

  def self.js_string_escape!(value : String) : String
    js_string_escape(value)
  end
end

def with_tmpdir(& : String ->)
  base = begin
    Dir.tempdir
  rescue
    "/tmp"
  end

  dir = File.join(base, "import-map-spec-#{Random::Secure.hex(12)}")
  FileUtils.mkdir_p(dir)

  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
