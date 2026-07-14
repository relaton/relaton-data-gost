# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem. The GOST flavor lives inside
# it at lib/relaton/gost/. Pinned to feat/gost-flavor in relaton/relaton#57
# until that PR merges, then flip back to main.
gem "relaton",
    git: "https://github.com/relaton/relaton.git",
    branch: "feat/gost-flavor"

# pubid v2 (with GOST support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. Pinned to the
# rt-new-lutaml-model branch (where metanorma/pubid#108 merged).
gem "pubid",
    git: "https://github.com/metanorma/pubid.git",
    branch: "rt-new-lutaml-model"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
