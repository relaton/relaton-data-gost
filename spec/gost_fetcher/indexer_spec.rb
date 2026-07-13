# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe GostFetcher::Indexer do
  let(:data_dir) { Dir.mktmpdir("gost-index-data") }
  let(:tmp_root) { Dir.mktmpdir("gost-index-root") }
  let(:index_file) { File.join(tmp_root, "index-v1.yaml") }
  let(:index_v2_file) { File.join(tmp_root, "index-v2.yaml") }
  let(:store) { GostFetcher::YamlStore.new(data_dir) }

  after do
    FileUtils.rm_rf(data_dir)
    FileUtils.rm_rf(tmp_root)
  end

  it "produces index-v1.yaml sorted by filename" do
    write_yaml("gost-14946-82",     "GOST 14946-82",     "14946")
    write_yaml("gost-r-34.12-2015", "GOST R 34.12-2015", "34.12")

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: nil,
    )

    contents = File.read(index_file)
    expect(contents).to include("GOST 14946-82")
    expect(contents).to include("GOST R 34.12-2015")
  end

  it "produces index-v2.yaml with structured pubids" do
    write_yaml("gost-r-34.12-2015", "GOST R 34.12-2015", "34.12")

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: index_v2_file,
    )

    v2 = File.read(index_v2_file)
    expect(v2).to include("pubid:gost:standard")
    expect(v2).to include("34.12")
  end

  it "warns and continues when a file has no docidentifier" do
    store.write("broken", { "type" => "standard", "title" => [] })
    expect { described_class.build(data_dir: data_dir, index_file: index_file) }
      .to output(/no docidentifier/).to_stderr
  end

  def write_yaml(stem, content, docnumber)
    hash = {
      "id" => stem.upcase.tr("-", " ").then { |s| s.sub(/GOST R/, "GOST-R") },
      "type" => "standard",
      "title" => [{ "language" => "eng", "content" => "Test", "type" => "main" }],
      "docidentifier" => [{
        "content" => content,
        "type" => "GOST", "primary" => true,
      }],
      "docnumber" => docnumber,
      "ext" => { "doctype" => { "content" => "national" }, "flavor" => "gost" },
    }
    store.write(stem, hash)
  end
end
