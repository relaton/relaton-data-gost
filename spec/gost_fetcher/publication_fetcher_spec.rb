# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe GostFetcher::PublicationFetcher do
  let(:data_dir) { Dir.mktmpdir("gost-data") }
  let(:store) { GostFetcher::YamlStore.new(data_dir) }
  let(:source) { FakeSource.new(entries) }

  after { FileUtils.rm_rf(data_dir) }

  it "emits one YAML per source entry" do
    fetcher = described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [source],
    )
    fetcher.run

    files = Dir[File.join(data_dir, "*.yaml")].sort
    expect(files.length).to eq(2)
    expect(File.basename(files.first)).to eq("gost-14946-82.yaml")
  end

  it "writes the canonical docidentifier content for a national standard" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [national_source],
    ).run

    data = store.read("gost-r-34.12-2015")
    expect(data["docidentifier"].first["content"])
      .to eq("GOST R 34.12-2015")
    expect(data["docidentifier"].first["primary"]).to be(true)
  end

  it "writes the GOST ext block with urn and doctype=national" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [national_source],
    ).run

    data = store.read("gost-r-34.12-2015")
    expect(data["ext"]["urn"]).to eq("urn:gost:std:r:34.12:2015")
    expect(data["ext"]["flavor"]).to eq("gost")
    expect(data["ext"]["doctype"]["content"]).to eq("national")
  end

  it "writes doctype=interstate for bare-GOST entries" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [interstate_source],
    ).run

    data = store.read("gost-14946-82")
    expect(data["ext"]["doctype"]["content"]).to eq("interstate")
  end

  it "uses the entry title for the title field when present" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [national_source],
    ).run

    data = store.read("gost-r-34.12-2015")
    expect(data["title"].first["content"]).to eq("Block cipher")
  end

  # Lightweight fake source — real instances only; no doubles.
  class FakeSource < GostFetcher::Sources::Base
    def initialize(entries_data)
      @entries_data = entries_data
    end

    def each_entry
      return enum_for(:each_entry) unless block_given?

      @entries_data.each { |d| yield GostFetcher::SourceEntry.new(**d) }
    end
  end

  def entries
    [
      { scope: nil, number: "14946", year: "82",
        title: "Cylindrical helical compression springs" },
      { scope: "russian", number: "34.11", year: "2012",
        title: "Hash function" },
    ]
  end

  def national_source
    FakeSource.new([
      { scope: "russian", number: "34.12", year: "2015", title: "Block cipher" },
    ])
  end

  def interstate_source
    FakeSource.new([
      { scope: nil, number: "14946", year: "82",
        title: "Cylindrical helical compression springs" },
    ])
  end
end
