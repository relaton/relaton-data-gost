# frozen_string_literal: true

require "fileutils"
require "json"

module GostFetcher
  # Downloads PDFs and caches them under +cache_dir+ with a human-
  # browsable filename (typically the docid's filename stem, e.g.
  # +gost-r-34.12-2015+).
  class PdfDownloader
    MANIFEST_FILE = "manifest.json".freeze

    attr_reader :cache_dir, :http_backend

    def initialize(cache_dir: "pdfs", http_backend: GostFetcher::Http.backend)
      @cache_dir = File.expand_path(cache_dir)
      @http_backend = http_backend
      FileUtils.mkdir_p(@cache_dir)
    end

    def fetch(url, name:)
      path = path_for(name)
      return path if File.exist?(path)

      FileUtils.mkdir_p(File.dirname(path))
      body = http_backend.get(url)
      File.binwrite(path, body)
      record_in_manifest(url, name)
      path
    end

    def cached?(name)
      File.exist?(path_for(name))
    end

    def path_for(name)
      File.join(@cache_dir, "#{safe_name(name)}.pdf")
    end

    def url_for(name)
      manifest["name_to_url"][safe_name(name)]
    end

    private

    def safe_name(name)
      name.to_s.gsub(/[^\w.\-]/, "_")
    end

    def manifest
      @manifest ||= begin
        path = File.join(@cache_dir, MANIFEST_FILE)
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          { "name_to_url" => {}, "url_to_name" => {} }
        end
      end
    end

    def record_in_manifest(url, name)
      sname = safe_name(name)
      manifest["name_to_url"][sname] = url
      manifest["url_to_name"][url] = sname
      File.write(File.join(@cache_dir, MANIFEST_FILE), JSON.pretty_generate(manifest))
    end
  end
end
