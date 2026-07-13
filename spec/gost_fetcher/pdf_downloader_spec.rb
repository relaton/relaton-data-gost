# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe GostFetcher::PdfDownloader do
  let(:cache_dir) { Dir.mktmpdir("gost-pdfs") }
  let(:fake_http) { GostFetcher::Http::Fake.new(url => "%PDF-1.4 fake") }
  let(:url) { "https://example.com/gost-34.12-2015.pdf" }
  let(:downloader) { described_class.new(cache_dir: cache_dir, http_backend: fake_http) }

  after { FileUtils.rm_rf(cache_dir) }

  it "downloads and caches the PDF under <name>.pdf" do
    path = downloader.fetch(url, name: "gost-r-34.12-2015")
    expect(File.basename(path)).to eq("gost-r-34.12-2015.pdf")
    expect(File.binread(path)).to eq("%PDF-1.4 fake")
  end

  it "is idempotent — does not re-download on second call" do
    path = downloader.fetch(url, name: "gost-r-34.12-2015")
    first_mtime = File.mtime(path)
    sleep 0.01
    downloader.fetch(url, name: "gost-r-34.12-2015")
    expect(File.mtime(path)).to eq(first_mtime)
  end

  it "records the URL in the manifest" do
    downloader.fetch(url, name: "gost-r-34.12-2015")
    expect(downloader.url_for("gost-r-34.12-2015")).to eq(url)
  end

  it "reports cached? correctly" do
    expect(downloader.cached?("gost-r-34.12-2015")).to be(false)
    downloader.fetch(url, name: "gost-r-34.12-2015")
    expect(downloader.cached?("gost-r-34.12-2015")).to be(true)
  end
end
