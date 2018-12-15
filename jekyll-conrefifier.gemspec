# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "version"

Gem::Specification.new do |spec|
  spec.name          = "jekyll-conrefifier"
  spec.version       = JekyllConrefifier::VERSION
  spec.authors       = ["Garen J. Torikian"]
  spec.email         = ["gjtorikian@gmail.com"]
  spec.summary       = "Allows you to use Liquid variables in various places in Jekyll"
  spec.description   = <<~DESCRIPTION
    A set of monkey patches that allows you to use Liquid variables
    in a variety of places in Jekyll, like frontmatter or data files.
  DESCRIPTION
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r!^bin/!) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r!^(test)/!)
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "~> 2.3"

  spec.add_development_dependency "jekyll", "~> 2.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rubocop-jekyll", "~> 0.4"
end
