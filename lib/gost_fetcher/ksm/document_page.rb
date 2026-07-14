# frozen_string_literal: true

require "nokogiri"

module GostFetcher
  module Ksm
    # Parses a KSM document detail page (/catalog/document/<id>/)
    # into a metadata record.
    #
    # Selectors used (verified against the KSM template):
    #
    #   .prod-cat             — category ("ГОСТ Р")
    #   .detail-code          — primary designation
    #   .detail-code-alt      — alt designation (often same)
    #   .prod-badge           — status badge ("Действующий")
    #   .detail-title         — Russian title (uppercase)
    #   .detail-title-alt     — alt title (often same; English when available)
    #   .detail-meta-grid     — grid of metadata rows
    #   .detail-tag           — one keyword per span
    #
    # The meta grid uses .dm-label / .dm-value pairs:
    #   Страниц (pages), Язык (language), МКС (ICS),
    #   Разработчик (developer).
    class DocumentPage
      Result = Struct.new(
        :doc_id,
        :category,
        :designation,
        :designation_alt,
        :status,
        :title,
        :title_alt,
        :pages,
        :language,
        :ics_code,
        :developer,
        :keywords,
        keyword_init: true,
      )

      # Russian status terms → English equivalents used in relaton's
      # status.stage.content. Keep this mapping in one place so the
      # scraper and the YAML agree on vocabulary.
      STATUS_MAP = {
        "ДЕЙСТВУЮЩИЙ"          => "active",
        "Действующий"          => "active",
        "Действует"            => "active",
        "Принят в МГС (не введен)" => "adopted-pending",
        "Отменён"              => "withdrawn",
        "Отменен"              => "withdrawn",
        "Заменяющий"           => "replaces",
      }.freeze

      def self.parse(html, doc_id: nil)
        new(html, doc_id: doc_id).parse
      end

      def initialize(html, doc_id: nil)
        @doc = Nokogiri::HTML(html.to_s, nil, "UTF-8")
        @doc_id = doc_id
      end

      def parse
        meta = parse_meta_grid

        Result.new(
          doc_id:          @doc_id,
          category:        text_at(".prod-cat"),
          designation:     text_at(".detail-code"),
          designation_alt: text_at(".detail-code-alt"),
          status:          mapped_status(text_at(".prod-badge")),
          title:           text_at(".detail-title"),
          title_alt:       text_at(".detail-title-alt"),
          pages:           meta["Страниц"]&.to_i,
          language:        meta["Язык"],
          ics_code:        meta["МКС"],
          developer:       meta["Разработчик"],
          keywords:        keywords,
        )
      end

      private

      def text_at(selector)
        el = @doc.at_css(selector)
        return nil unless el

        text = el.text.to_s.strip
        text.empty? ? nil : text
      end

      # Build a {label => value} hash from the .detail-meta-grid rows.
      # Each row has a .dm-label and a .dm-value child.
      def parse_meta_grid
        @doc.css(".detail-meta-item").each_with_object({}) do |item, acc|
          label = text_within(item, ".dm-label")
          value = text_within(item, ".dm-value")
          acc[label] = value if label && value
        end
      end

      def text_within(scope, selector)
        el = scope.at_css(selector)
        return nil unless el

        text = el.text.to_s.strip
        text.empty? ? nil : text
      end

      def keywords
        @doc.css(".detail-tag").map { |tag| tag.text.to_s.strip }.reject(&:empty?)
      end

      def mapped_status(raw)
        return nil unless raw

        # Try exact match first, then case-insensitive.
        STATUS_MAP[raw] || STATUS_map_ci(raw)
      end

      def STATUS_map_ci(raw)
        STATUS_MAP.find { |k, _| k.casecmp(raw).zero? }&.last || raw
      end
    end
  end
end
