# frozen_string_literal: true

require "nokogiri"

module GostFetcher
  module Ksm
    # Parses a KSM catalogue listing page (
    # /catalog/category/<slug>/?page=N) into summary records.
    #
    # Each .prod-card on the page corresponds to one document. The
    # parser extracts the document's KSM id, category, designation,
    # title, status badge, page count, ICS code, and detail-page URL.
    #
    # Pagination is detected from the .pagination links — the parser
    # reports the highest page number seen so the source knows when to
    # stop.
    class CataloguePage
      Summary = Struct.new(
        :doc_id,         # "77227"
        :category,       # "ГОСТ" | "ГОСТ Р" | ...
        :designation,    # "ГОСТ 31425.5-2025 / ISO 9902-5:2001"
        :title,          # "Машины текстильные..."
        :status,         # "Принят в МГС (не введен)" | nil
        :pages,          # 12 | nil
        :ics_code,       # "17.140.20" | nil
        :detail_url,     # "/catalog/document/77227/"
        keyword_init: true,
      )

      Result = Struct.new(:items, :last_page, keyword_init: true)

      def self.parse(html)
        new(html).parse
      end

      def initialize(html)
        @doc = Nokogiri::HTML(html.to_s, nil, "UTF-8")
      end

      def parse
        Result.new(items: items, last_page: last_page)
      end

      private

      def items
        @doc.css(".prod-card").map do |card|
          summary_from_card(card)
        end.compact
      end

      def summary_from_card(card)
        link = card.at_css(".prod-top")
        return nil unless link

        detail_url = link["href"]
        doc_id = doc_id_from_url(detail_url)
        return nil unless doc_id

        Summary.new(
          doc_id: doc_id,
          category: text_at(card, ".prod-cat"),
          designation: text_at(card, ".prod-code"),
          title: text_at(card, ".prod-title"),
          status: text_at(card, ".prod-badge"),
          pages: parse_pages(text_at(card, ".prod-meta span:first-child")),
          ics_code: ics_from_meta(card),
          detail_url: detail_url,
        )
      end

      def doc_id_from_url(url)
        return nil unless url

        m = url.to_s.match(%r{/catalog/document/(\d+)/?})
        m && m[1]
      end

      def text_at(node, selector)
        el = node.at_css(selector)
        return nil unless el

        text = el.text.to_s.strip
        text.empty? ? nil : text
      end

      # "12 стр." → 12 ; returns nil if no digit run found.
      def parse_pages(text)
        return nil unless text

        m = text.match(/(\d+)/)
        m && m[1].to_i
      end

      # The second span in .prod-meta carries the ICS code (e.g.
      # "17.140.20"). Returns nil when absent (some docs lack ICS).
      def ics_from_meta(card)
        spans = card.css(".prod-meta span")
        spans.each do |span|
          text = span.text.to_s.strip
          return text if text.match?(/\A\d+\.\d+(?:\.\d+)?\z/)
        end
        nil
      end

      # Highest page number referenced in the pagination block. KSM
      # emits direct links to first/last and a few around the current
      # page; the highest ?page=N value is the last page.
      def last_page
        pages = @doc.css('a[href*="page="]')
                    .map { |a| a["href"][/page=(\d+)/, 1] }
                    .compact
                    .map(&:to_i)
        pages.max || 1
      end
    end
  end
end
