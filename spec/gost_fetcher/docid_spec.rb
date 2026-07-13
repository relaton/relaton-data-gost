# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::Docid do
  describe ".from_national" do
    it "builds a GOST R (national) Docid" do
      d = described_class.from_national("34.12", year: "2015")
      expect(d.scope).to eq("russian")
      expect(d.number).to eq("34.12")
      expect(d.year).to eq("2015")
      expect(d.doctype).to eq("national")
    end

    it "accepts a numeric year as integer" do
      expect(described_class.from_national("34.12", year: 2015).year).to eq("2015")
    end
  end

  describe ".from_interstate" do
    it "builds a GOST (interstate) Docid" do
      d = described_class.from_interstate("14946", year: "82")
      expect(d.scope).to be_nil
      expect(d.number).to eq("14946")
      expect(d.year).to eq("82")
      expect(d.doctype).to eq("interstate")
    end
  end

  describe ".from_string" do
    it "routes GOST R strings to national Docids" do
      d = described_class.from_string("GOST R 34.12-2015")
      expect(d.scope).to eq("russian")
      expect(d.number).to eq("34.12")
      expect(d.doctype).to eq("national")
    end

    it "routes bare GOST strings to interstate Docids" do
      d = described_class.from_string("GOST 14946-82")
      expect(d.scope).to be_nil
      expect(d.number).to eq("14946")
      expect(d.doctype).to eq("interstate")
    end
  end

  describe "#to_s" do
    it "renders the canonical GOST R citation" do
      expect(described_class.from_national("34.12", year: "2015").to_s)
        .to eq("GOST R 34.12-2015")
    end

    it "renders the canonical GOST citation" do
      expect(described_class.from_interstate("14946", year: "82").to_s)
        .to eq("GOST 14946-82")
    end
  end

  describe "#id" do
    it "uses dash-separated form for national" do
      expect(described_class.from_national("34.12", year: "2015").id)
        .to eq("GOST-R-34.12-2015")
    end

    it "uses dash-separated form for interstate" do
      expect(described_class.from_interstate("14946", year: "82").id)
        .to eq("GOST-14946-82")
    end
  end

  describe "#filename_stem" do
    it "is lowercase and filesystem-safe" do
      expect(described_class.from_national("34.12", year: "2015").filename_stem)
        .to eq("gost-r-34.12-2015")
    end
  end

  describe "#urn" do
    it "delegates to Pubid::Gost for national" do
      expect(described_class.from_national("34.12", year: "2015").urn)
        .to eq("urn:gost:std:r:34.12:2015")
    end

    it "delegates to Pubid::Gost for interstate" do
      expect(described_class.from_interstate("14946", year: "82").urn)
        .to eq("urn:gost:std:14946:82")
    end
  end

  describe "equality" do
    it "treats identical Docids as equal" do
      a = described_class.from_national("34.12", year: "2015")
      b = described_class.from_national("34.12", year: "2015")
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "distinguishes national from interstate with same number" do
      a = described_class.from_national("34.12", year: "2015")
      b = described_class.from_interstate("34.12", year: "2015")
      expect(a).not_to eq(b)
    end
  end

  it "is frozen on construction" do
    expect(described_class.from_national("34.12", year: "2015")).to be_frozen
  end
end
