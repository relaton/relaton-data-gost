# frozen_string_literal: true

module GostFetcher
  # Value object that produces a relaton-compatible +source+ hash with
  # the correct +type+ for the kind of location it represents. Three
  # constructors remove the "local path tagged as website" class of bug.
  class Source
    def self.url(url)
      { "type" => "website", "content" => url }
    end

    # A path on the gost.ru portal — resolves against GostFetcher::BASE_URL.
    # If the input is already an HTTP(S) URL, returned as-is.
    def self.gost(path)
      return url(path) if path.to_s.start_with?("http")

      base = GostFetcher::BASE_URL.chomp("/")
      path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
      url("#{base}#{path}")
    end

    def self.webpage(url)
      { "type" => "website", "content" => url }
    end

    def self.local(path)
      { "type" => "file", "content" => path }
    end
  end
end
