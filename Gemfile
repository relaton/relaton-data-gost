# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem. The GOST flavor lives inside
# it at lib/relaton/gost/, landed on main by relaton/relaton#57.
gem "relaton",
    git: "https://github.com/relaton/relaton.git",
    branch: "main"

# pubid v2 (with GOST support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. Targets main
# (Adobe re-landed on main via pubid/pubid#114).
gem "pubid",
    git: "https://github.com/metanorma/pubid.git",
    branch: "main"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
