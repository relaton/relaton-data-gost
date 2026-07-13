# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe GostFetcher::YamlStore do
  let(:dir) { Dir.mktmpdir("gost-yaml-store") }
  let(:store) { described_class.new(dir) }

  after { FileUtils.rm_rf(dir) }

  it "writes a YAML file under the directory" do
    store.write("gost-r-34.12-2015", minimal_hash)
    expect(File.exist?(File.join(dir, "gost-r-34.12-2015.yaml"))).to be(true)
  end

  it "is idempotent — skips when overwrite: false and file exists" do
    store.write("gost-r-34.12-2015", minimal_hash)
    expect(store.write("gost-r-34.12-2015", minimal_hash, overwrite: false)).to be(false)
  end

  it "round-trips a hash through write → read" do
    store.write("gost-r-34.12-2015", minimal_hash)
    data = store.read("gost-r-34.12-2015")
    expect(data["docidentifier"].first["content"])
      .to eq("GOST R 34.12-2015")
  end

  it "exposes each_yaml as an iterator over the directory" do
    store.write("gost-r-34.12-2015", minimal_hash)
    keys = store.each_yaml.map { |name, _path| name }
    expect(keys).to include("gost-r-34.12-2015")
  end

  it "reports existence via exist?" do
    expect(store.exist?("gost-r-34.12-2015")).to be(false)
    store.write("gost-r-34.12-2015", minimal_hash)
    expect(store.exist?("gost-r-34.12-2015")).to be(true)
  end

  def minimal_hash
    {
      "id" => "GOST-R-34.12-2015",
      "type" => "standard",
      "title" => [{
        "language" => "eng", "content" => "Block cipher", "type" => "main",
      }],
      "docidentifier" => [{
        "content" => "GOST R 34.12-2015",
        "type" => "GOST", "primary" => true,
      }],
      "ext" => { "doctype" => { "content" => "national" }, "flavor" => "gost" },
    }
  end
end
