module ImportMap
  class Manager
    getter base : Map = Map.new

    @namespace : Hash(String, Map) = {} of String => Map
    @cache : Hash(String?, Tuple(String, Array(String))) = {} of String? => Tuple(String, Array(String))
    @resolver : Proc(String, String) = ->(path : String) { path }

    @@instance : Manager? = nil

    def self.instance
      @@instance ||= new
    end

    # Replaces the global singleton with a fresh, empty manager and returns it.
    # Intended for test isolation and dev-time reloading.
    def self.reset! : Manager
      @@instance = new
    end

    def resolver=(resolver : Proc(String, String))
      @resolver = resolver
      @cache.clear
    end

    def pin(*args, **kwargs)
      @base.pin(*args, **kwargs)
      @cache.clear
    end

    def pin_all_from(*args, **kwargs)
      @base.pin_all_from(*args, **kwargs)
      @cache.clear
    end

    def namespace(name : String, &)
      map = (@namespace[name] ||= Map.new)
      with map yield
      @cache.clear
      map
    end

    def json(ns : String? = nil) : String
      cached(ns)[0]
    end

    def preloads(ns : String? = nil) : Array(String)
      cached(ns)[1].dup
    end

    private def cached(ns : String? = nil) : Tuple(String, Array(String))
      @cache[ns] ||= begin
        map = resolve_map(ns)
        {map.to_json_string(@resolver), map.preload_urls(@resolver)}
      end
    end

    private def resolve_map(ns : String? = nil) : Map
      return @base if ns.nil?

      ns_map = @namespace[ns]? || raise NamespaceError.new("Unknown namespace: #{ns}")

      @base.merge(ns_map)
    end
  end
end
