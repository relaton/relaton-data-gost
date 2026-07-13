# frozen_string_literal: true

require "thor"

module GostFetcher
  class Scrape < Thor
    def self.exit_on_failure? = true

    default_task :fetch

    desc "fetch", "Fetch GOST standards from registered sources into data/"
    method_option :source, type: :string, repeatable: true,
                            desc: "Source name to fetch (e.g. catalogue). Defaults to all."
    method_option :pdfs, type: :boolean, default: false,
                         desc: "Download PDFs and OCR cover pages for fields not in source metadata."
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    def fetch
      sources = build_sources(options[:source])
      if sources.empty?
        say "No sources selected. Available: catalogue", :red
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

    def build_sources(names, **)
      names = Array(names).map(&:to_s)
      available = available_sources
      names.empty? ? available.values : names.filter_map { |n| available[n] }
    end

    # Source registry. Adding a new source = adding one entry here and
    # one Sources::<Name> file. OCP at the source level.
    def available_sources
      {
        "catalogue" => GostFetcher::Sources::Catalogue.new,
      }
    end
  end
end
