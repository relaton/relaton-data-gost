# frozen_string_literal: true

require "date"
require "fileutils"
require "open3"

module GostFetcher
  # Orchestrates the full pipeline:
  #
  #   Sources::Base#each_entry
  #       │ yields Entry (scope, number, year, paths)
  #       ▼
  #   PdfDownloader#fetch            (for URL-based sources)
  #       │
  #       ▼
  #   text = pdftotext -layout -l 1  (preferred)
  #   text = CoverPageOcr#ocr_first_page  (fallback for scans)
  #       │
  #       ▼
  #   CoverPageParser.parse(text)    → Result Struct
  #       │
  #       ▼
  #   build hash via Relaton::Gost::Item.from_hash
  #       │
  #       ▼
  #   YamlStore.write(filename_stem, hash)
  class PublicationFetcher
    attr_reader :data_dir, :yaml_store, :sources,
                :pdf_downloader, :cover_page_ocr

    def initialize(data_dir:, yaml_store:, sources:,
                   pdf_downloader: nil, cover_page_ocr: nil)
      @data_dir = data_dir
      @yaml_store = yaml_store
      @sources = Array(sources)
      @pdf_downloader = pdf_downloader
      @cover_page_ocr = cover_page_ocr
    end

    def run
      FileUtils.mkdir_p(@data_dir)

      @sources.each do |source|
        emit_from_source(source)
      end
    end

    private

    def emit_from_source(source)
      source.each_entry do |entry|
        emit_entry(entry)
      rescue StandardError => e
        warn "  ERROR emitting #{entry&.filename || entry.inspect}: #{e.message}"
      end
    end

    def emit_entry(entry)
      docid = entry.to_docid
      cover = cover_for(entry, name: docid.filename_stem)

      hash = build_hash(entry, docid, cover)
      yaml_store.write(docid.filename_stem, hash)
    end

    def cover_for(entry, name:)
      pdf_path = pdf_path_for(entry, name: name)
      return nil unless pdf_path

      text = extract_first_page_text(pdf_path)
      text = ocr_first_page(pdf_path, name: name) if (text.nil? || text.strip.empty?) && @cover_page_ocr
      return nil unless text && !text.strip.empty?

      GostFetcher::CoverPageParser.parse(text)
    rescue StandardError => e
      warn "    cover page parse: #{e.message}"
      nil
    end

    def pdf_path_for(entry, name:)
      return entry.absolute_path if entry.absolute_path && File.exist?(entry.absolute_path)
      return nil unless @pdf_downloader && entry.bytes_url

      @pdf_downloader.fetch(entry.bytes_url, name: name)
    end

    def extract_first_page_text(pdf_path)
      out, status = Open3.capture2("pdftotext", "-layout", "-l", "1", pdf_path, "-")
      return nil unless status.success? && !out.empty?

      out
    rescue StandardError
      nil
    end

    def ocr_first_page(pdf_path, name:)
      return nil unless @cover_page_ocr

      @cover_page_ocr.ocr_first_page(pdf_path, name: name)
    end

    def build_hash(entry, docid, cover)
      title_text = cover&.title || entry.title || docid.to_s
      title_lang = entry.language&.match?(/^Рус/i) ? "rus" : "eng"
      script_lang = title_lang == "rus" ? "Cyrl" : "Latn"
      date = year_to_date(cover&.year || docid.year)
      status = entry.status || "in-force"

      hash = {
        "id" => docid.id,
        "type" => "standard",
        "title" => [{
          "language" => title_lang,
          "content" => title_text,
          "type" => "main",
        }],
        "docidentifier" => [{
          "content" => docid.to_s,
          "type" => "GOST",
          "primary" => true,
        }],
        "docnumber" => docid.number,
        "contributor" => contributors_for(entry),
        "language" => [title_lang],
        "script" => [script_lang],
        "status" => { "stage" => { "content" => status } },
        "ext" => ext_block(entry, docid, cover),
      }
      apply_source!(hash, entry)
      apply_dates!(hash, date)
      apply_copyright!(hash, date)
      hash
    end

    def contributors_for(entry)
      list = [GostFetcher.gost_publisher_contributor]
      return list unless entry.developer && !entry.developer.empty?

      list << {
        "role" => [{ "type" => "author" }],
        "organization" => { "name" => [{ "content" => entry.developer }] },
      }
      list
    end

    def year_to_date(year)
      return nil unless year

      y = year.to_i
      y += 1900 if y < 100 && y >= 30  # "82" → 1982 (assumes 20th century for 2-digit years)
      y += 2000 if y < 30              # "15" → 2015 (21st century for very low 2-digit years)
      Date.new(y, 1, 1)
    rescue ArgumentError
      nil
    end

    def ext_block(entry, docid, cover)
      ext = {
        "doctype" => { "content" => docid.doctype },
        "flavor" => "gost",
      }
      urn = cover&.urn || docid.urn
      ext["urn"] = urn if urn && !urn.empty?
      ext["webpage"] = entry.web_url if entry.web_url
      ext["ics_code"] = entry.ics_code if entry.ics_code
      ext["developer"] = entry.developer if entry.developer
      ext["pages"] = entry.pages.to_s if entry.pages
      ext["keywords"] = Array(entry.keywords).map { |k| { "content" => k } } if entry.keywords&.any?
      ext["designation_original"] = entry.designation_full if entry.designation_full
      ext
    end

    def apply_source!(hash, entry)
      return unless entry.bytes_url

      hash["source"] = [GostFetcher::Source.url(entry.bytes_url)]
    end

    def apply_dates!(hash, date)
      return unless date

      hash["date"] = [{ "type" => "published", "from" => date.iso8601 }]
    end

    def apply_copyright!(hash, date)
      return unless date

      hash["copyright"] = [{
        "from" => date.year.to_s,
        "owner" => [{ "organization" => GostFetcher.gost_org_hash }],
      }]
    end
  end
end
