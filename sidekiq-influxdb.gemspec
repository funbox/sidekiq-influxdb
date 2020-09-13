lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "sidekiq/influxdb/version"

Gem::Specification.new do |spec|
  spec.name          = "sidekiq-influxdb"
  spec.version       = Sidekiq::InfluxDB::VERSION
  spec.authors       = ["Ilya Vassilevsky"]
  spec.email         = ["vassilevsky@gmail.com"]

  spec.summary       = "Writes Sidekiq job metrics to InfluxDB"
  spec.homepage      = "https://github.com/vassilevsky/sidekiq-influxdb"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "influxdb"
  spec.add_runtime_dependency "sidekiq"
end
