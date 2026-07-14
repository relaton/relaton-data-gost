# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::Ksm::CataloguePage do
  let(:html) do
    File.read(File.expand_path("../../fixtures/ksm/catalogue-gost-page1.html", __dir__),
              encoding: "UTF-8")
  end

  describe ".parse" do
    subject(:result) { described_class.parse(html) }

    it "extracts every .prod-card on the page" do
      expect(result.items.size).to be > 5
    end

    it "parses a known summary correctly" do
      first = result.items.first
      expect(first.doc_id).to eq("77227")
      expect(first.category).to eq("ГОСТ")
      expect(first.designation).to start_with("ГОСТ 31425.5-2025")
      expect(first.detail_url).to eq("/catalog/document/77227/")
      expect(first.status).to eq("Принят в МГС (не введен)")
      expect(first.pages).to eq(12)
      expect(first.ics_code).to eq("17.140.20")
    end

    it "reports the last page number from the pagination block" do
      expect(result.last_page).to eq(1506)
    end
  end
end
