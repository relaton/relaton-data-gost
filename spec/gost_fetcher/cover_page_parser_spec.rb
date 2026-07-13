# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::CoverPageParser do
  describe ".parse" do
    it "extracts scope/number/year from a canonical GOST R cover (English)" do
      text = <<~TEXT
        GOST R 34.12-2015
        Information technology — Cryptographic data security — Block cipher
      TEXT
      result = described_class.parse(text)
      expect(result.scope).to eq("russian")
      expect(result.number).to eq("34.12")
      expect(result.year).to eq("2015")
      expect(result.title)
        .to eq("Information technology — Cryptographic data security — Block cipher")
    end

    it "handles Cyrillic surface form" do
      text = "ГОСТ Р 34.11-94\nКриптографическая защита информации"
      result = described_class.parse(text)
      expect(result.scope).to eq("russian")
      expect(result.number).to eq("34.11")
      expect(result.year).to eq("94")
    end

    it "handles interstate (bare GOST) form" do
      result = described_class.parse("GOST 14946-82\nCylindrical helical compression springs")
      expect(result.scope).to be_nil
      expect(result.number).to eq("14946")
      expect(result.year).to eq("82")
    end

    it "captures the URN line when present" do
      text = "GOST R 34.12-2015\nBlock cipher\nurn:gost:std:r:34.12:2015"
      expect(described_class.parse(text).urn).to eq("urn:gost:std:r:34.12:2015")
    end

    it "raises on empty input" do
      expect { described_class.parse("") }
        .to raise_error(GostFetcher::CoverPageParser::MissingCoverFields)
    end
  end
end
