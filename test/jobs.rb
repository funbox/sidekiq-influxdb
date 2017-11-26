require "sidekiq/influxdb/server_middleware"

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::InfluxDB::ServerMiddleware, influxdb_client: InfluxDB::Client.new('test', time_precision: 'ms')
  end
end

# Test jobs

class FooJob
  include Sidekiq::Worker

  def perform
    sleep rand 1..3
  end
end

class BarJob
  include Sidekiq::Worker

  def perform
    sleep rand 0..3
    nil.join
  end
end

5.times do
  [FooJob, BarJob].sample.perform_async
  sleep rand 0..2
end
