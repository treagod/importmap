module ImportMap
  class Map
    URI_SCHEME_REGEX = /\A[a-z][a-z0-9+\-.]*:\/\//i

    @entries : Hash(String, Entry) = {} of String => Entry
    @directories : Array(MappedDir) = [] of MappedDir

    protected def entries
      @entries
    end

    protected def directories
      @directories
    end

    # Adds a new pin. Raises `DuplicatePinError` if the specifier already exists and `override` is not set to true.
    def pin(specifier : String, to url : String, preload : Bool = true, override : Bool = false)
      if @entries.has_key?(specifier) && !override
        raise DuplicatePinError.new("Specifier #{specifier} already pinned")
      end
      @entries[specifier] = Entry.new(specifier, url, preload)
    end

    # Map an entire directory of modules under an optional namespace.
    def pin_all_from(dir : String, *, under : String? = nil, to : String? = nil, preload : Bool = true)
      @directories << MappedDir.new(dir, under, to, preload)
    end

    def to_json_string(resolver : Proc(String, String)? = nil) : String
      entries = expanded_entries

      String.build do |io|
        JSON.build(io) do |json|
          json.object do
            json.field "imports" do
              json.object do
                entries.each do |specifier, entry|
                  json.field specifier do
                    url = resolver && needs_resolve?(entry.url) ? resolver.call(entry.url) : entry.url
                    json.string url
                  end
                end
              end
            end
          end
        end
      end
    end

    def preload_urls(resolver : Proc(String, String)? = nil) : Array(String)
      entries = expanded_entries
      urls = Array(String).new(entries.size)
      entries.each_value do |entry|
        next unless entry.preload?

        url = resolver && needs_resolve?(entry.url) ? resolver.call(entry.url) : entry.url
        urls << url
      end
      urls
    end

    def merge(other : Map) : Map
      merged = Map.new

      @entries.each do |specifier, entry|
        merged.entries[specifier] = entry
      end
      other.entries.each do |specifier, entry|
        merged.entries[specifier] = entry
      end
      @directories.each do |dir|
        merged.directories << dir
      end
      other.directories.each do |dir|
        merged.directories << dir
      end

      merged
    end

    private def needs_resolve?(url : String) : Bool
      !URI_SCHEME_REGEX.matches?(url)
    end

    private def expanded_entries : Hash(String, Entry)
      entries = @entries.dup
      @directories.each do |mapping|
        each_js_module(mapping.dir) do |_, relative_path|
          module_name = build_module_name(relative_path, mapping.under)
          target_path = build_target_path(relative_path, mapping.to || mapping.under)

          entries[module_name] = Entry.new(module_name, target_path, mapping.preload?)
        end
      end
      entries
    end

    private def each_js_module(dir : String, & : String, String ->)
      base = Path.new(dir).expand
      base_str = base.to_s
      return unless Dir.exists?(base_str)

      pattern = "#{base_str}/**/*.{js,mjs}"
      Dir.glob(pattern).sort.each do |abs|
        abs_path = Path.new(abs)
        rel = abs_path.relative_to(base).to_s
        yield abs, rel
      end
    end

    private def build_module_name(relative_path : String, under : String?) : String
      normalized = relative_path.gsub('\\', '/')
      no_ext = normalized.sub(/\.(mjs|js)\z/, "")
      under ? "#{under}/#{no_ext}" : no_ext
    end

    private def build_target_path(relative_path : String, to_prefix : String?) : String
      normalized = relative_path.gsub('\\', '/')
      to_prefix ? "#{to_prefix}/#{normalized}" : normalized
    end
  end
end
