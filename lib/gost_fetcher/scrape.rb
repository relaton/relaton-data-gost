# frozen_string_literal: true

require "thor"

module GostFetcher
  class Scrape < Thor
    def self.exit_on_failure? = true

    default_task :fetch

    desc "fetch", "Fetch GOST standards from registered sources into data/"
    method_option :source, type: :string, repeatable: true,
                            desc: "Source name (catalogue, ksm). Defaults to all."
    method_option :category, type: :string, repeatable: true,
                             desc: "KSM category slug (gost, gost-r). Defaults to both."
    method_option :limit, type: :numeric, default: nil,
                          desc: "Cap items per category (KSM source). Useful for test runs."
    method_option :delay, type: :numeric, default: 1.0,
                          desc: "Polite delay between KSM HTTP requests (seconds)."
    method_option :cache_dir, type: :string, default: "sources/ksm-cache",
                              desc: "Where to cache KSM HTML responses."
    method_option :pdfs, type: :boolean, default: false,
                         desc: "Download PDFs and OCR cover pages for fields not in source metadata."
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    def fetch
      sources = build_sources(options[:source], options.to_h)
      if sources.empty?
        say "No sources selected. Available: catalogue, ksm", :red
        exit 1
      end

      store = GostFetcher::YamlStore.new(options[:data_dir])
      pdf_downloader = options[:pdfs] ? GostFetcher::PdfDownloader.new(cache_dir: options[:pdfs_dir]) : nil
      cover_ocr = options[:pdfs] ? GostFetcher::CoverPageOcr.new : nil

      say "Fetching GOST standards (sources=#{sources.map(&:class).map(&:name).inspect}, pdfs=#{options[:pdfs]})", :cyan
      GostFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir],
        yaml_store: store,
        sources: sources,
        pdf_downloader: pdf_downloader,
        cover_page_ocr: cover_ocr,
      ).run

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "index", "Rebuild index-v1.yaml + index-v2.yaml from data/*.yaml"
    def index
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    private

    def build_sources(names, opts)
      names = Array(names).map(&:to_s)
      available = available_sources(opts)
      names.empty? ? available.values : names.filter_map { |n| available[n] }
    end

    # Source registry. Adding a new source = adding one entry here and
    # one Sources::<Name> file. OCP at the source level.
    def available_sources(opts)
      ksm = build_ksm_source(opts)
      {
        "catalogue" => GostFetcher::Sources::Catalogue.new,
        "ksm"       => ksm,
      }
    end

    def build_ksm_source(opts)
      categories = Array(opts[:category]).map(&:to_s)
      categories = GostFetcher::Sources::Ksm::CATEGORY_SLUGS.keys if categories.empty?

      client = GostFetcher::Ksm::Client.new(
        delay: opts[:delay],
        cache_dir: opts[:cache_dir],
      )

      GostFetcher::Sources::Ksm.new(
        categories: categories,
        client: client,
        per_category_limit: opts[:limit],
      )
    end
  end
end
