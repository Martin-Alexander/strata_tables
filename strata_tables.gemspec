require_relative "lib/strata_tables/version"

Gem::Specification.new do |spec|
  spec.name = "strata_tables"
  spec.version = StrataTables::VERSION
  spec.authors = ["Martin-Alexander"]
  spec.email = ["martingianna@gmail.com"]

  spec.summary = "TODO"
  spec.description = "TODO"
  spec.homepage = "https://github.com/Martin-Alexander/strata_tables"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # spec.metadata["allowed_push_host"] = "TODO'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Martin-Alexander/strata_tables"
  spec.metadata["changelog_uri"] = "https://github.com/Martin-Alexander/strata_tables/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "pg"
  spec.add_development_dependency "database_cleaner-active_record"
  spec.add_development_dependency "rails"
end
