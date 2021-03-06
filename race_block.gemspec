# frozen_string_literal: true

require_relative "lib/race_block/version"

Gem::Specification.new do |spec|
  spec.name          = "race_block"
  spec.version       = RaceBlock::VERSION
  spec.authors       = ["Joey Paris"]
  spec.email         = ["joey@leadjig.com"]

  spec.summary       = "A Ruby code block wrapper to help prevent race conditions " \
                       "across multiple threads and even separate servers."
  # spec.description   = "TODO: Write a longer description or delete this line."
  spec.homepage      = "https://rubygems.org/gems/race_block"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/joeyparis/race_block"
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "13.0"
  spec.add_development_dependency "redis", "4.0.1"
  spec.add_development_dependency "rspec", "3.10"
  spec.add_development_dependency "rubocop", "1.17"
  spec.add_development_dependency "simplecov", "0.21.2"
  spec.add_development_dependency "thwait", "0.2.0"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
