# frozen_string_literal: true

module GostFetcher
  # Parses the cover-page text of a GOST standard PDF into structured
  # fields. GOST cover pages vary in layout but reliably contain:
  #
  #   ГОСТ Р 34.12-2015
  #   Information technology — Cryptographic data security — Block cipher
  #
  # Or in Russian:
  #
  #   ГОСТ Р 34.12-2015
  #   Информационная технология — Криптографическая защита информации — Блочный шифр
  #
  # The parser scans for *field patterns* (regex per field) rather than
  # positional lines, so a different layout doesn't break it.
  class CoverPageParser
    Result = Struct.new(
      :scope,        # "russian" | nil (interstate)
      :number,       # "34.12", "14946"
      :year,         # "82", "2015"
      :title,        # "Block cipher" / etc.
      :urn,          # if present on cover
      keyword_init: true,
    )

    class MissingCoverFields < StandardError; end

    # Lines like:
    #   ГОСТ Р 34.12-2015
    #   ГОСТ 14946-82
    #   GOST R 34.12-2015
    #   GOST 14946-82
    NUMBER_LINE = /\A(?:ГОСТ|GOST)\s+(Р\s+|R\s+)?(\d+(?:\.\d+)*)-(\d{2,4})\z/i.freeze

    def self.parse(text)
      new(text).parse
    end

    def initialize(text)
      @text = text.to_s
      @lines = @text.lines.map(&:strip).reject(&:empty?)
    end

    def parse
      raise MissingCoverFields, "no text to parse" if @lines.empty?

      Result.new(
        scope:  scope,
        number: number,
        year:   year,
        title:  title,
        urn:    urn,
      )
    end

    private

    def number_line_match
      @number_line_match ||= @lines.each do |line|
        m = line.match(NUMBER_LINE)
        return m if m
      end
    end

    def scope
      m = number_line_match
      return nil unless m

      m[1].nil? || m[1].strip.empty? ? nil : "russian"
    end

    def number
      number_line_match && number_line_match[2]
    end

    def year
      number_line_match && number_line_match[3]
    end

    # The title is the first non-empty line that isn't the number line.
    def title
      @lines.each do |line|
        next if line.match?(NUMBER_LINE)
        next if line.match?(/\Aurn:gost:/i)

        return line
      end
      nil
    end

    def urn
      @lines.each do |line|
        return line.strip if line.match?(/\Aurn:gost:/i)
      end
      nil
    end
  end
end
