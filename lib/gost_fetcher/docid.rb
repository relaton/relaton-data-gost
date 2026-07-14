# frozen_string_literal: true

require "pubid"
require "pubid/gost"

module GostFetcher
  # Immutable value object representing a GOST document identifier.
  # Thin wrapper over Pubid::Gost for parse/render/URN concerns; owns
  # the data-repo-specific filename and id forms.
  class Docid
    attr_reader :national, :number, :year, :doctype

    def initialize(national:, number:, year: nil, doctype: nil)
      @national = national   # true (GOST R) | false (GOST interstate)
      @number = number
      @year = year
      @doctype = doctype || (national ? "national" : "interstate")
      freeze
    end

    def self.from_national(number, year: nil)
      new(national: true, number: number.to_s, year: year&.to_s)
    end

    def self.from_interstate(number, year: nil)
      new(national: false, number: number.to_s, year: year&.to_s)
    end

    def self.from_string(str)
      id = Pubid::Gost.parse(str)

      # Unwrap IdenticalAdoption to get the base GOST
      base = if id.is_a?(Pubid::Gost::Identifiers::IdenticalAdoption)
               id.base
             else
               id
             end

      national = base.is_a?(Pubid::Gost::Identifiers::NationalStandard)
      new(
        national: national,
        number: base.number,
        year: base.year,
      )
    end

    def to_s
      pubid.to_s
    end

    def id
      to_s.tr(" ", "-")
    end

    def filename_stem
      id.downcase.tr(" ", "_").gsub("/", "-").gsub("(", "").gsub(")", "").gsub(/[^a-z0-9_.-]/, "")
    end

    def urn
      pubid.to_urn
    end

    def ==(other)
      other.is_a?(Docid) &&
        other.national == national &&
        other.number == number &&
        other.year == year
    end
    alias eql? ==

    def hash
      [national, number, year].hash
    end

    def pubid
      klass = national ? Pubid::Gost::Identifiers::NationalStandard
                       : Pubid::Gost::Identifiers::InterstateStandard
      klass.new(number: number, year: year)
    end
  end
end
