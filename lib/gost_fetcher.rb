# frozen_string_literal: true

require "relaton/bib"
require "relaton/gost"

# GostFetcher scrapes GOST (Russian federal standards) sources into
# Relaton YAML files under data/.
module GostFetcher
  # Landing-page URL for the GOST national-standards catalogue.
  BASE_URL = "https://www.gost.ru/portal/gost/home/standarts/catalognational".freeze

  # English-language catalogue mirror.
  BASE_URL_EN =
    "https://www.gost.ru/portal/eng/home/standarts/catalognational".freeze

  GOST_NAME = "Federal Agency on Technical Regulating and Metrology".freeze
  GOST_ABBR = "GOST".freeze

  # Mapping from doctype key to its descriptive title. New doctypes
  # are added here; nothing else in the codebase branches on doctype
  # (OCP). Mirrors Relaton::Gost::Doctype::TYPES.
  DOCTYPES = {
    "interstate"    => { title: "Interstate Standard" },
    "national"      => { title: "National Standard" },
    "preliminary"   => { title: "Preliminary Standard" },
    "methodological" => { title: "Methodological Document" },
  }.freeze

  def self.gost_org_hash
    {
      "name" => [{ "content" => GOST_NAME }],
      "abbreviation" => { "content" => GOST_ABBR },
    }
  end

  def self.gost_publisher_contributor
    {
      "role" => [{ "type" => "publisher" }],
      "organization" => gost_org_hash,
    }
  end

  # autoload entries — defined here so `require "gost_fetcher"` makes
  # every submodule available lazily. No `require_relative` in lib/.
  autoload :Docid,              "gost_fetcher/docid"
  autoload :Source,             "gost_fetcher/source"
  autoload :SourceEntry,        "gost_fetcher/source_entry"
  autoload :Http,               "gost_fetcher/http"
  autoload :YamlStore,          "gost_fetcher/yaml_store"
  autoload :PdfDownloader,      "gost_fetcher/pdf_downloader"
  autoload :CoverPageOcr,       "gost_fetcher/cover_page_ocr"
  autoload :CoverPageParser,    "gost_fetcher/cover_page_parser"
  autoload :PublicationFetcher, "gost_fetcher/publication_fetcher"
  autoload :Indexer,            "gost_fetcher/indexer"
  autoload :Scrape,             "gost_fetcher/scrape"

  # KSM client namespace — the new-shop.ksm.kz scraper lives here.
  module Ksm
    autoload :Client,         "gost_fetcher/ksm/client"
    autoload :CataloguePage,  "gost_fetcher/ksm/catalogue_page"
    autoload :DocumentPage,   "gost_fetcher/ksm/document_page"
  end

  # Sources namespace — each source lives under GostFetcher::Sources.
  module Sources
    autoload :Base,      "gost_fetcher/sources/base"
    autoload :Catalogue, "gost_fetcher/sources/catalogue"
    autoload :Ksm,       "gost_fetcher/sources/ksm"
  end
end
