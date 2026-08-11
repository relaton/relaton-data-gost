# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Bibliographic dataset of GOST (Russian federal standards — Гостстандарт)
publications, stored as Relaton YAML under `data/`. Initial scope
covers GOST interstate standards (bare `GOST <number>-<year>`) and
GOST R Russian national standards (`GOST R <number>-<year>`).

The scraper lives in this repo (`lib/gost_fetcher/`); the data is
consumed by the unified `relaton` gem via the `Relaton::Gost` flavor
that lives inside the gem at `lib/relaton/gost/`
(PR [relaton/relaton#57](https://github.com/relaton/relaton/pull/57),
tracks issue [relaton/relaton#41](https://github.com/relaton/relaton/issues/41))).

Sibling to `relaton-data-iala` and `relaton-data-adobe` under
`/Users/mulgogi/src/relaton/`. The architecture, file layout, OCR
pipeline, and indexing contract mirror those repos.

## Identifier model

GOST identifiers have the shape `GOST [R ]<number>[-<year>]`. Two
variants appear in the wild:

- **Interstate** — `GOST <number>-<year>` (CIS). Example: `GOST 14946-82`.
- **Russian national** — `GOST R <number>-<year>`. Example: `GOST R 34.12-2015`.

Both Latin (`GOST`) and Cyrillic (`ГОСТ`) surface forms are parseable;
the canonical render is Latin for international audiences.

`<number>` is a digit run, optionally dotted (`34.12`, `8.595`, `1.0`).
`<year>` is 2 or 4 digits, preserved verbatim.

URN format:
- Interstate: `urn:gost:std:<number>[:<year>]`
- Russian national: `urn:gost:std:r:<number>[:<year>]`

## Source data

The current source is `Sources::Catalogue` — a table-driven list of
commonly-cited GOST standards (cryptographic and metrology). Real
scraping of gost.ru is a future enhancement; the portal is JS-heavy.

Adding a new entry to the catalogue = appending to the `CATALUE`
constant in `lib/gost_fetcher/sources/catalogue.rb`. Each entry is a
hash with the keys accepted by `GostFetcher::SourceEntry.new`.

## Repo layout

```
data/                     # YAML per GOST standard (e.g. gost-r-34.12-2015.yaml)
Gemfile                   # psych pin + relaton + pubid (git main)
.github/workflows/
  deploy.yml              # GitHub Pages index build (relaton/support caller)
crawler.rb                # entry point → GostFetcher::Indexer.build
check_data.rb             # round-trip validator, exit 1 on mismatch
exe/gost-fetch            # binstub ($LOAD_PATH + require "gost_fetcher")
lib/gost_fetcher.rb       # module + constants + autoload entries
lib/gost_fetcher/
  docid.rb                # GostFetcher::Docid value object
  source.rb               # .url / .gost / .local constructors
  source_entry.rb         # GostFetcher::SourceEntry — uniform Entry type
  http.rb                 # Http seam (NetHttp + Fake adapters)
  yaml_store.rb           # owns all YAML I/O, uses Relaton::Gost::Item
  sources/
    base.rb               # Sources::Base — abstract #each_entry
    catalogue.rb          # Sources::Catalogue — table-driven GOST list
  pdf_downloader.rb       # caches PDFs by URL hash under pdfs/
  cover_page_ocr.rb       # GLM-OCR wrapper
  cover_page_parser.rb    # OCR/text → structured fields
  publication_fetcher.rb  # orchestrates → emits YAML
  indexer.rb              # GostFetcher::Indexer.build (clean-rebuild v1 + v2)
  scrape.rb               # Thor subclass (fetch + index tasks)
spec/gost_fetcher/        # rspec specs (no doubles — real instances)
spec/deploy_workflow_spec.rb  # guards the deploy.yml caller contract
sources/                  # gitignored (anchored /sources/) — cloned-source cache
pdfs/                     # gitignored PDF cache
pdfs/ocr-cache/           # gitignored OCR markdown cache
index-v1.yaml             # generated, committed (flat string docid index)
index-v2.yaml             # generated, committed (structured pubid index)
```

## Architecture

All modules use Ruby `autoload` declared in `lib/gost_fetcher.rb`.
No `require_relative` anywhere in `lib/`. The binstub adds `lib/` to
`$LOAD_PATH` and calls `require "gost_fetcher"`.

Dependency injection mirrors Adobe/IALA: fetchers accept `yaml_store:`
and `http_backend:` parameters; specs install `GostFetcher::Http::Fake`.

`GostFetcher::YamlStore` owns all YAML I/O (UTF-8, idempotent,
serialized via `Relaton::Gost::Item`). No `File.write` outside
`YamlStore`.

`GostFetcher::Docid` is a thin wrapper over `Pubid::Gost` for parse/
render/URN concerns. The `id` field uses the dash-separated form
(e.g. `GOST-R-34.12-2015`) so the filename stem is filesystem-safe;
the indexer reconstructs the canonical citation form before parsing
via `Pubid::Gost`.

`GostFetcher::SourceEntry` is the uniform entry type yielded by every
source. Each entry knows how to build its own Docid via `#to_docid`
(polymorphism, not type-dispatch in the orchestrator).

## Companion repos that must move in lockstep

| Repo | Path | Branch base | Adds |
|------|------|-------------|------|
| `relaton-data-gost` (here) | `src/relaton/relaton-data-gost` | `main` | Scraper, `data/*.yaml`, indexes |
| `relaton` (unified gem) | `src/relaton/relaton` | `main` (merged via PR [relaton/relaton#57](https://github.com/relaton/relaton/pull/57)) | `lib/relaton/gost/*` inside the unified gem |
| `pubid` | `src/mn/pubid` | `main` (merged via PR [metanorma/pubid#108](https://github.com/metanorma/pubid/pull/108)) | `lib/pubid/gost/*` (Standard identifier) |

Both flavor PRs have merged, so the `Gemfile` tracks `main` for
`relaton` and `pubid`. Neither feature branch exists any more — a stale
`branch:` pin makes `bundle install` fail outright.

## Commands

```bash
bundle install
bundle exec gost-fetch                                # scrape all sources, write data/
bundle exec gost-fetch --source=catalogue             # narrow to one source
bundle exec gost-fetch --pdfs                         # also download/OCR cover pages
bundle exec gost-fetch index                          # rebuild index-v1 + index-v2
bundle exec ruby crawler.rb                           # rebuild indexes only
bundle exec ruby check_data.rb                        # round-trip validate data/
bundle exec rspec spec/                               # run specs
```

## Crawler + check_data contracts

`crawler.rb` → `GostFetcher::Indexer.build` indexes every
`data/*.yaml` by primary docid into `index-v1.yaml` (string docid →
file) and `index-v2.yaml` (structured `Pubid::Gost` identifier → file,
`pubid_class: Pubid::Gost::Identifier`). Calls `remove_all` first so
both indexes are rebuilt from scratch each run.

`check_data.rb` round-trips every YAML through
`Relaton::Gost::Item.from_yaml` → `to_yaml` and diffs against the
source. Exit 1 on any byte mismatch. GOST `ext` fields round-trip
natively because they're typed on `Relaton::Gost::Ext` — **no merge
hack**.

## GitHub Pages

`.github/workflows/deploy.yml` calls the shared reusable workflow
`relaton/support/.github/workflows/data-deploy.yml@main`, which runs
`relaton index` over `data/` and publishes a self-contained,
crawler-indexable site to Pages (relaton/relaton#83). There is no
Jekyll, no `_config.yml`, no `Gemfile.deploy`.

- `source: git` is a **temporary pin** — no released relaton-cli ships
  the `index` command yet, so the default `source: gem` would fail.
  Drop the input once one does.
- Branding (`favicon`, `description`) came from
  `relaton/support/data-index/generated/gost_config.yml`. The page
  title is derived from the repo name (`GOST Index`), so no `title:`.
- `relaton index` reads `data/` directly and never touches
  `index-v1.yaml` / `index-v2.yaml` — **keep those anyway**, relaton
  fetchers and other consumers still read them.
- Pages must be enabled once per repo: **Settings → Pages → Source:
  GitHub Actions**.
- Triggers deviate from the sibling callers on purpose: no
  `pull_request:` and no `tags: [ v* ]`, because the shared workflow
  publishes only when the ref is the default *branch* — either trigger
  would pay for the full build and then skip the deploy. A
  `concurrency: pages` group serialises the cron, the crawler's push
  and manual dispatches, which Pages would otherwise reject.

`spec/deploy_workflow_spec.rb` parses the workflow and pins that
contract (shared-workflow ref, declared input names, triggers).

## Gemfile (template)

```ruby
gem "psych", "~> 5.2.6"
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
gem "pubid",   git: "https://github.com/metanorma/pubid.git",
               branch: "main"
gem "thor", "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false
```

Both flavor PRs (relaton/relaton#57, metanorma/pubid#108) have merged,
so both pins track `main`. HTTPS git sources so the GH Action can
clone anonymously.

## Conventions

- **Always read/write YAML with `encoding: "UTF-8"`** — GOST titles
  may contain Cyrillic text (ГОСТ, Р) and em-dashes.
- **Pin `psych ~> 5.2.6`** — 5.3.0 silently breaks the round-trip.
- **GitHub Actions reuse `relaton/support` workflows** — do not write
  custom ones. Same `check_data.yml` + `crawler.yml` + `keep-alive.yml`
  shape as Adobe.
- **Strict fetches — no fallbacks.** When a map is missing a key,
  `.fetch(key)` raises. Silent defaults produce malformed data.
- **Never use `double()` in specs** — instantiate real objects or use
  `Struct.new` for plain data.
- **Never use `require_relative`** in library code — Ruby `autoload`
  declared in the immediate parent namespace's file.
- **Never use `send` to private, `instance_variable_set/get`,
  `respond_to?` for type checking.**
- **Never commit to `main`, never push tags, never add AI attribution.**

## Reference files in sibling repos

- `relaton-data-adobe/CLAUDE.md` — architectural pattern source.
- `relaton-data-adobe/lib/adobe_fetcher/` — copy/adapt each file.
- `relaton-data-iala/lib/iala_fetcher/` — alternative pattern source.
- `relaton/relaton/lib/relaton/gost/` — `Relaton::Gost` in-monorepo
  flavor (this repo's companion).
- `mn/pubid/lib/pubid/gost/` — `Pubid::Gost` flavor.
- `relaton/relaton#41` — the parent issue tracking this work.
- `relaton/relaton#57` — the GOST flavor PR.
