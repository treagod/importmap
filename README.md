# importmap.cr ‑ A framework‑agnostic import‑map shard for Crystal

> **Load JavaScript modules without bundlers**
> Define pins in Crystal, merge them per‑namespace, and render a `<script type="importmap">` tag at runtime.

[![GitHub Release](https://img.shields.io/github/v/release/treagod/importmap?style=flat)](https://github.com/treagod/importmap/releases)
[![importmap.cr Specs](https://github.com/treagod/importmap/actions/workflows/specs.yml/badge.svg)](https://github.com/treagod/importmap/actions/workflows/specs.yml)
[![QA](https://github.com/treagod/importmap/actions/workflows/qa.yml/badge.svg)](https://github.com/treagod/importmap/actions/workflows/qa.yml)

---

## ✨ Features

* **Crystal DSL** – declare pins and namespaces in pure Crystal code.
* **Namespaced import maps** – serve different JS sets for *public*, *admin*, etc.
* **Module‑preload links** – automatic `<link rel="modulepreload">` for every pin (opt‑out supported).
* **Pluggable resolver** – hook in your asset pipeline to rewrite `/js/app.js` → `/assets/app‑abc123.js`.
* **Zero runtime overhead** – import‑map JSON is cached on boot.

---

## 📦 Installation

Add the shard to your `shard.yml` and run `shards install`.

```yaml
dependencies:
  importmap:
    github: treagod/importmap
    version: "~> 0.1.0"
```

## 🚀 Quick start

1. Configure pins

```crystal
require "importmap"

ImportMap.draw do
  # Base pins (preload = true by default)
  pin "stimulus", "/js/stimulus.js"

  namespace "admin" do
    pin "admin-ui", "/js/admin.js", preload: false # opt‑out
  end
end
```

2. (Optional) integrate a resolver

```crystal
ImportMap.resolver = ->(path : String) { "/assets#{path}?v=abc" }
```

3. Render the tags

```crystal
ImportMap.tag

# admin namespace with an custom entrypoint
ImportMap.tag("admin", entrypoint: "admin-ui")
```

Result:

```html
<link rel="modulepreload" href="/js/stimulus.js">
<script type="importmap">{"imports":{"stimulus":"/js/stimulus.js"}}</script>

<!-- admin namespace -->
<link rel="modulepreload" href="/js/stimulus.js">
<script type="importmap" data-namespace="admin">{"imports":{"stimulus":"/js/stimulus.js","admin-ui":"/js/admin.js"}}</script>
<script type="module">import "admin-ui"</script>
```

## 📁 Pin entire directories

Use `pin_all_from` to automatically expose every `.js`/`.mjs` file in a directory under a namespace. This mirrors Rails' importmap ergonomics for Stimulus controllers or other entrypoints.

```crystal
ImportMap.draw do
  pin "@hotwired/stimulus", to: "vendor/stimulus.js"
  pin_all_from "assets/controllers", under: "controllers", to: "controllers"
end
```

- `under:` controls the import specifier namespace (`controllers/menu_controller` in the example above).
- `to:` controls the logical asset path that gets passed to your resolver. Omit it to use the same prefix as `under` (or the raw relative path if `under` is `nil`).
- `preload:` defaults to `true`, matching `pin`.

`pin_all_from` entries participate in the same caching as regular pins, so calling `ImportMap.draw` (or `ImportMap::Manager.instance.pin_all_from`) followed by `ImportMap.tag` keeps runtime overhead low.


## 📚 Roadmap

- CLI tool for pinning/unpinning CDN packages
- Static build command (importmap build)
- Vulnerability & outdated‑package audit
- Add importmap scopes

## 💡 Contributing

1. Fork, create a feature branch.
2. `shards install && crystal spec` (all tests should pass).
3. Open a PR!
