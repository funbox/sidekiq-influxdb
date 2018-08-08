require "sidekiq/middleware/server/influxdb"

module LooksLikeWork
  def perform
    logger.info "[#{self.class}] working..."
    sleep rand 1..3
  end
end

class FooJob
  include Sidekiq::Worker
  include LooksLikeWork
end

class BarJob
  include Sidekiq::Worker
  include LooksLikeWork
end

class IgnoredJob
  include Sidekiq::Worker
  include LooksLikeWork
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::InfluxDB,
              influxdb_client: InfluxDB::Client.new('test', time_precision: 'ms'),
              except: [IgnoredJob]
  end
end

12.times do
  [FooJob, BarJob, IgnoredJob].sample.perform_async
  sleep rand 0..2
end
