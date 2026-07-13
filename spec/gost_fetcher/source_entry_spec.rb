# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::SourceEntry do
  describe "#to_docid" do
    it "builds a national Docid when scope is 'russian'" do
      entry = described_class.new(scope: "russian", number: "34.12", year: "2015")
      docid = entry.to_docid
      expect(docid.scope).to eq("russian")
      expect(docid.number).to eq("34.12")
      expect(docid.doctype).to eq("national")
    end

    it "builds an interstate Docid when scope is nil" do
      entry = described_class.new(scope: nil, number: "14946", year: "82")
      docid = entry.to_docid
      expect(docid.scope).to be_nil
      expect(docid.doctype).to eq("interstate")
    end

    it "passes year through" do
      entry = described_class.new(scope: "russian", number: "34.12", year: "2015")
      expect(entry.to_docid.year).to eq("2015")
    end

    it "passes title through (used by PublicationFetcher for the title field)" do
      entry = described_class.new(
        scope: "russian", number: "34.12", year: "2015",
        title: "Block cipher",
      )
      expect(entry.title).to eq("Block cipher")
    end
  end

  describe "accessors" do
    it "defaults every location field to nil" do
      entry = described_class.new(scope: "russian", number: "34.12")
      expect(entry.absolute_path).to be_nil
      expect(entry.web_url).to be_nil
      expect(entry.bytes_url).to be_nil
      expect(entry.filename).to be_nil
      expect(entry.year).to be_nil
      expect(entry.title).to be_nil
    end
  end
end
