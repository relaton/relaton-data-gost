# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::Http do
  describe "::Fake" do
    it "returns the body for a known URL" do
      fake = described_class::Fake.new("https://example.com/x" => "BODY")
      expect(fake.get("https://example.com/x")).to eq("BODY")
    end

    it "invokes a Proc fixture" do
      fake = described_class::Fake.new(
        "https://example.com/y" => ->(_url) { "DYNAMIC" },
      )
      expect(fake.get("https://example.com/y")).to eq("DYNAMIC")
    end

    it "raises KeyError on unknown URL" do
      fake = described_class::Fake.new({})
      expect { fake.get("https://example.com/unknown") }
        .to raise_error(KeyError)
    end
  end

  describe "::NetHttp" do
    it "is the default backend" do
      expect(described_class.backend).to be_a(described_class::NetHttp)
    end
  end

  describe "error classes" do
    it "exposes the standard hierarchy" do
      expect(described_class::TooManyRedirects).to be < described_class::Error
      expect(described_class::BadStatus).to be < described_class::Error
      expect(described_class::Timeout).to be < described_class::Error
    end
  end

  after do
    described_class.backend = described_class::NetHttp.new
  end
end
