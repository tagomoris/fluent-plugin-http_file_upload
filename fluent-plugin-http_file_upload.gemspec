# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-http_file_upload"
  spec.version       = "0.0.0"
  spec.authors       = ["TAGOMORI Satoshi"]
  spec.email         = ["tagomoris@gmail.com"]

  spec.summary       = %q{Fluentd output plugin to send buffered data to http servers as HTTP file upload}
  spec.description   = %q{This fluentd output plugin sends data as files, to HTTP servers which provides features for file uploaders.}
  spec.homepage      = "https://github.com/tagomoris/fluent-plugin-http_file_upload"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "fluentd", "~> 0.12.10"
  spec.add_runtime_dependency "httpclient", "~> 2.6"
  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "test-unit", "~> 3.0"
end
