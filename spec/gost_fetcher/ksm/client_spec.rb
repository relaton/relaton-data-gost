# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe GostFetcher::Ksm::Client do
  let(:cache_dir) { Dir.mktmpdir("ksm-cache") }
  let(:fake_http) { GostFetcher::Http::Fake.new(url => "BODY-CONTENT") }
  let(:url) { "https://new-shop.ksm.kz/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1" }
  let(:client) { described_class.new(cache_dir: cache_dir, delay: 0, http_backend: fake_http) }

  after { FileUtils.rm_rf(cache_dir) }

  it "fetches the URL through the HTTP backend" do
    expect(client.get("/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1"))
      .to eq("BODY-CONTENT")
  end

  it "caches responses on disk under cache_dir/<sha1>.html" do
    client.get("/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1")
    cached = Dir[File.join(cache_dir, "*.html")]
    expect(cached.size).to eq(1)
    expect(File.read(cached.first, encoding: "UTF-8")).to eq("BODY-CONTENT")
  end

  it "writes a sidecar .url file for cache inspection" do
    client.get("/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1")
    url_files = Dir[File.join(cache_dir, "*.url")]
    expect(url_files.size).to eq(1)
    expect(File.read(url_files.first, encoding: "UTF-8")).to eq(url)
  end

  it "serves from cache on the second call (no backend hit)" do
    # First call consumes the fake's table entry is fine; Fake returns
    # the same body each call. The test confirms the cache short-circuit
    # by inspecting mtimes — a cache hit shouldn't re-fetch.
    client.get("/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1")
    path = Dir[File.join(cache_dir, "*.html")].first
    first_mtime = File.mtime(path)
    sleep 0.02
    client.get("/catalog/category/%D0%B3%D0%BE%D1%81%D1%82/?page=1")
    expect(File.mtime(path)).to eq(first_mtime)
  end

  it "accepts a full URL or a path (host-relative)" do
    expect(client.get(url)).to eq("BODY-CONTENT")
  end
end
