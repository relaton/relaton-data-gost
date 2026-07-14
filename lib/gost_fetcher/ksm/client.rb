# frozen_string_literal: true

require "fileutils"
require "digest"
require "time"

module GostFetcher
  module Ksm
    # Polite HTTP client for new-shop.ksm.kz. Adds three things the
    # bare Http::NetHttp backend doesn't:
    #
    #   * Disk cache under +cache_dir+, keyed by URL SHA1. Repeated
    #     fetches are free, which matters because the KSM scrape is
    #     ~85k requests across two categories.
    #   * Polite delay between requests (default 1.0s). Token-bucket
    #     style: sleeps since-last-request if needed.
    #   * Exponential backoff on 429 / 5xx (4 attempts, 30s → 60s → 120s).
    #
    # The client is KSM-specific (encodes the host, retry policy, and
    # cache key shape) — it's not a general HTTP util.
    class Client
      HOST = "https://new-shop.ksm.kz".freeze
      DEFAULT_DELAY = 1.0
      DEFAULT_CACHE_DIR = "sources/ksm-cache".freeze

      attr_reader :cache_dir, :delay, :http_backend

      def initialize(cache_dir: nil, delay: nil,
                     http_backend: GostFetcher::Http.backend)
        @cache_dir = File.expand_path(cache_dir || DEFAULT_CACHE_DIR)
        @delay = (delay || DEFAULT_DELAY).to_f
        @http_backend = http_backend
        FileUtils.mkdir_p(@cache_dir)
        @last_request_at = 0.0
      end

      # GET a path on the KSM host. Returns the response body (String,
      # UTF-8 encoded). Caches by URL SHA1 under +cache_dir+; subsequent
      # calls for the same path skip the network. Empty responses are
      # NOT cached (they poison the cache for the next run).
      def get(path)
        url = absolute_url(path)
        key = cache_key(url)
        cached = read_cache(key)
        return cached if cached

        throttle!
        body = fetch_with_retry(url)
        return body unless body && !body.empty?

        # Re-tag the body as UTF-8 (Net::HTTP returns ASCII-8BIT for
        # non-ASCII content). KSM pages are UTF-8; re-tagging in place
        # avoids a costly byte-level transcode.
        body = body.dup.force_encoding("UTF-8")
        write_cache(key, url, body)
        body
      end

      private

      def absolute_url(path)
        return path if path.start_with?("http")

        "#{HOST}#{path.start_with?("/") ? path : "/#{path}"}"
      end

      def cache_key(url)
        Digest::SHA1.hexdigest(url)
      end

      def read_cache(key)
        path = File.join(@cache_dir, "#{key}.html")
        return nil unless File.exist?(path) && File.size(path).positive?

        File.read(path, encoding: "UTF-8")
      end

      def write_cache(key, url, body)
        # Net::HTTP returns bodies tagged ASCII-8BIT regardless of the
        # server's declared charset. KSM pages are UTF-8; re-tag in
        # place (no byte conversion) so File.write doesn't try to
        # transcode and fail on the first Cyrillic byte.
        utf8_body = body.to_s.dup.force_encoding("UTF-8")
        # Body + sidecar URL file (for debugging / cache inspection).
        File.write(File.join(@cache_dir, "#{key}.html"), utf8_body, encoding: "UTF-8")
        File.write(File.join(@cache_dir, "#{key}.url"), url, encoding: "UTF-8")
      rescue StandardError
        # Cache-write failure shouldn't crash the scrape.
      end

      def throttle!
        return if @delay <= 0

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request_at
        sleep(@delay - elapsed) if elapsed < @delay
        @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def fetch_with_retry(url, attempts: 4)
        delay = 30
        attempts.times do |n|
          return http_backend.get(url)
        rescue GostFetcher::Http::BadStatus => e
          raise if n == attempts - 1
          raise unless e.message.match?(/HTTP (429|5\d\d)/)

          warn "  KSM #{e.message}; retry in #{delay}s (attempt #{n + 1}/#{attempts})"
          sleep delay
          delay = [delay * 2, 300].min
        end
      end
    end
  end
end
