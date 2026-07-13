# frozen_string_literal: true

require "pubid"
require "pubid/gost"

module GostFetcher
  # Immutable value object representing a GOST document identifier
  # across its observed forms:
  #
  #   * citation form   — "GOST R 34.12-2015", "GOST 14946-82"
  #   * URN             — "urn:gost:std:r:34.12:2015"
  #
  # The object is a thin wrapper over Pubid::Gost for parse/render/URN
  # concerns; it owns the data-repo-specific filename and id forms.
  class Docid
    attr_reader :scope, :number, :year, :doctype

    def initialize(scope:, number:, year: nil, doctype: nil)
      @scope = scope    # "russian" | nil (interstate)
      @number = number  # "34.12", "14946", "8.595"
      @year = year      # "82", "2015", nil
      @doctype = doctype
      freeze
    end

    # --- Constructors ---

    # Builds a Docid for a Russian national standard (GOST R).
    #   from_national("34.12", year: "2015")
    def self.from_national(number, year: nil)
      new(scope: "russian", number: number.to_s, year: year&.to_s,
          doctype: "national")
    end

    # Builds a Docid for an interstate standard (bare GOST).
    #   from_interstate("14946", year: "82")
    def self.from_interstate(number, year: nil)
      new(scope: nil, number: number.to_s, year: year&.to_s,
          doctype: "interstate")
    end

    # Builds a Docid by delegating to Pubid::Gost for parsing.
    def self.from_string(str)
      id = Pubid::Gost.parse(str)
      new(scope: id.scope, number: id.number, year: id.year,
          doctype: id.scope == "russian" ? "national" : "interstate")
    end

    # --- Derived forms ---

    # The docidentifier.content string for relaton — the human-readable
    # citation form. Delegates to Pubid::Gost.
    def to_s
      pubid.to_s
    end

    # The relaton `id` field — the canonical parseable identifier.
    # Uses the citation form with spaces replaced by dashes so it's
    # filesystem-safe and round-trips through Pubid::Gost when split
    # back. Examples:
    #   "GOST R 34.12-2015" → "GOST-R-34.12-2015"
    #   "GOST 14946-82"     → "GOST-14946-82"
    def id
      to_s.tr(" ", "-")
    end

    # Filename-safe stem for the data/<stem>.yaml path.
    def filename_stem
      id.downcase.tr(" ", "_").gsub("/", "-").gsub(/[^a-z0-9_.-]/, "")
    end

    # URN, delegated to Pubid::Gost.
    def urn
      pubid.to_urn
    end

    # --- Equality ---

    def ==(other)
      other.is_a?(Docid) &&
        other.scope == scope &&
        other.number == number &&
        other.year == year &&
        other.doctype == doctype
    end
    alias eql? ==

    def hash
      [scope, number, year, doctype].hash
    end

    # --- Pubid bridge ---

    # Builds the equivalent Pubid::Gost identifier.
    def pubid
      Pubid::Gost::Identifiers::Standard.new(scope: scope, number: number, year: year)
    end
  end
end
