lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = "jekyll-conrefifier"
  spec.version       = JekyllConrefifier::VERSION
  spec.authors       = ["Garen J. Torikian"]
  spec.email         = ["gjtorikian@gmail.com"]
  spec.summary       = %q{Allows you to use Liquid variables in various places in Jekyll}
  spec.description   = %q{A set of monkey patches that allows you to use Liquid variables in a variety of places in Jekyll, like frontmatter or data files.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'jekyll',    '>= 2.0'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
