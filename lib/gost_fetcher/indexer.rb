# frozen_string_literal: true

require "relaton/index"
require "relaton/bib"
require "relaton/gost"

module GostFetcher
  # Builds the docid → file-path index over data/*.yaml using
  # relaton-index. Two index flavours, built in a single pass:
  #
  #   * index-v1.yaml  — flat string docid → file (uses docid.content)
  #   * index-v2.yaml  — structured pubid → file (uses item.id,
  #                     parsed via Pubid::Gost)
  module Indexer
    module_function

    def build(data_dir:, index_file:, index_v2_file: nil)
      idx = clean_index(file: index_file)
      pubid_class = resolve_pubid_class
      idx2 = structured_index(index_v2_file, pubid_class)
      base = File.dirname(File.expand_path(index_file))

      Dir[File.join(data_dir, "*.yaml")].sort.each do |f|
        item = Relaton::Gost::Item.from_yaml(File.read(f, encoding: "UTF-8"))
        docid = item.docidentifier.find(&:primary) || item.docidentifier.first
        unless docid
          warn "Error processing #{f}: no docidentifier"
          next
        end
        rel = File.expand_path(f).delete_prefix("#{base}/")
        idx.add_or_update docid.content, rel
        # index-v2 parses item.id (canonical form) rather than docid.content
        # for consistency. For GOST, item.id is the dash-separated form
        # (e.g. "GOST-R-34.12-2015") which round-trips through Pubid::Gost
        # after restoring the spaces.
        add_pubid(idx2, pubid_class, item.id, rel) if idx2
      rescue StandardError => e
        warn "Error processing #{f}: #{e.message}"
      end

      idx.save
      idx2&.save
      [idx, idx2]
    end

    def clean_index(file:, pubid_class: nil)
      idx = Relaton::Index.find_or_create :Gost, file: file, pubid_class: pubid_class
      idx.remove_all
      idx
    end

    def structured_index(file, pubid_class)
      return nil unless file

      clean_index(file: file, pubid_class: pubid_class)
    end

    def resolve_pubid_class
      begin
        require "pubid"
        Pubid::Gost::Identifier
      rescue LoadError, StandardError
        nil
      end
    end

    # item.id is the dash-separated form (e.g. "GOST-R-34.12-2015").
    # Restore spaces before parsing so Pubid::Gost sees the canonical
    # surface form. Round-trip stable because dashes only appear
    # between the original space-separated tokens.
    def add_pubid(idx2, pubid_class, content, rel)
      return unless pubid_class

      # "GOST-R-34.12-2015" → "GOST R 34.12-2015"
      canonical = content.sub(/\A(GOST)-([RP])/, '\1 \2').tr("-", " ").then do |s|
        # Reinsert the year-separator dash. The Pubid::Gost canonical
        # form keeps the year dash: "GOST 14946-82".
        s.sub(/(\d{1,5}) (\d{2,4})\z/, '\1-\2')
      end
      parsed = pubid_class.parse(canonical)
      idx2.add_or_update parsed, rel
    rescue StandardError => e
      warn "Skipping #{content} in index-v2: #{e.message}"
    end
  end
end
