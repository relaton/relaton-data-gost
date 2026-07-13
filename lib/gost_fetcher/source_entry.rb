# frozen_string_literal: true

module GostFetcher
  # Common base type for every entry yielded by a Source. Each entry
  # knows how to build its own Docid (polymorphism, not type-dispatch
  # in the orchestrator) and exposes the optional location fields
  # (filename, absolute_path, web_url, bytes_url) with nil defaults.
  #
  # For GOST Publications the optional +title+ rides along so the
  # resulting YAML's title field is populated.
  class SourceEntry
    attr_reader :scope, :number, :year, :title,
                :filename, :absolute_path, :web_url, :bytes_url

    # rubocop:disable Metrics/ParameterLists
    def initialize(scope:, number:, year: nil, title: nil, filename: nil,
                   absolute_path: nil, web_url: nil, bytes_url: nil)
      @scope         = scope
      @number        = number
      @year          = year
      @title         = title
      @filename      = filename
      @absolute_path = absolute_path
      @web_url       = web_url
      @bytes_url     = bytes_url
    end
    # rubocop:enable Metrics/ParameterLists

    # Builds the Docid for this entry. The dispatch is on +scope+
    # (data shape), not on entry class — the invariant is that an
    # entry's scope is either "russian" or nil (interstate).
    def to_docid
      if scope == "russian"
        GostFetcher::Docid.from_national(number, year: year)
      else
        GostFetcher::Docid.from_interstate(number, year: year)
      end
    end
  end
end
