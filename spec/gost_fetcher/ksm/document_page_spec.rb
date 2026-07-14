# frozen_string_literal: true

require "spec_helper"

RSpec.describe GostFetcher::Ksm::DocumentPage do
  let(:html) do
    File.read(File.expand_path("../../fixtures/ksm/document-77202.html", __dir__),
              encoding: "UTF-8")
  end

  describe ".parse" do
    subject(:result) { described_class.parse(html, doc_id: "77202") }

    it "captures doc_id, category, designation" do
      expect(result.doc_id).to eq("77202")
      expect(result.category).to eq("ГОСТ Р")
      expect(result.designation).to eq("ГОСТ Р 71039— 2023")
    end

    it "maps ДЕЙСТВУЮЩИЙ/Действующий status to 'active'" do
      expect(result.status).to eq("active")
    end

    it "extracts Russian title (uppercase)" do
      expect(result.title).to start_with("СВАИ БУРОНАБИВНЫЕ")
    end

    it "captures pages, language, ICS, developer from the meta grid" do
      expect(result.pages).to eq(20)
      expect(result.language).to eq("Русский")
      expect(result.ics_code).to eq("13.080.20")
      expect(result.developer).to eq("Российская Федерация")
    end

    it "extracts every keyword" do
      expect(result.keywords).to include("сваи буронабивные", "«стены в грунте»",
                                         "неразрушающий контроль", "сплошность")
      expect(result.keywords.size).to eq(8)
    end
  end
end
