require_relative "lib/strata_tables/version"

Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "strata_tables"
  s.version = StrataTables::VERSION
  s.summary = "Unintuitive temporal tables for ActiveRecord"
  s.description = "Unintuitive temporal tables for ActiveRecord"

  s.required_ruby_version = ">= 3.2.0"

  s.license = "MIT"

  s.authors = ["Martin-Alexander"]
  s.homepage = "https://github.com/Martin-Alexander/strata_tables"
  s.email = ["martingianna@gmail.com"]

  s.files = Dir["CHANGELOG.md", "LICENSE.txt", "README.md", "lib/**/*"]
  s.require_path = "lib"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/Martin-Alexander/strata_tables/issues",
    "changelog_uri" => "https://github.com/Martin-Alexander/strata_tables/CHANGELOG.md",
    "homepage_uri" => s.homepage,
    "source_code_uri" => "https://github.com/Martin-Alexander/strata_tables"
  }

  s.add_dependency "activerecord", ">= 7.0", "< 9.0"
  s.add_dependency "pg"
end
