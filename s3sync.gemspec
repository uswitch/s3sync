# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 's3sync/version'

Gem::Specification.new do |spec|
  spec.name          = "s3simplesync"
  spec.version       = S3sync::VERSION
  spec.authors       = ["Christian Blunden"]
  spec.email         = ["christian.blunden@gmail.com"]
  spec.description   = %q{Command line tool to sync the files within a folder to S3}
  spec.summary       = %q{Sync a folder with S3 bucket}
  spec.homepage      = "https://github.com/uswitch/s3sync"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency 'aws-sdk','~> 1.48.1'
end
