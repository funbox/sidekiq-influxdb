require 'sidekiq/api'

module Sidekiq
  module Metrics
    class Stats

      def initialize(
        influxdb_client:,
        series_name: 'sidekiq_stats',
        retention_policy: nil,
        tags: {}
      )
        @influxdb = influxdb_client
        @series = series_name
        @retention = retention_policy
        @tags = tags
      end

      def publish
        stats = Sidekiq::Stats.new.instance_variable_get(:@stats)
        stats.delete(:default_queue_latency)

        stats.each do |stat, size|
          save(
            tags: {stat: stat}.merge(@tags),
            values: {size: size}
          )
        end
      end

      private

      def save(data)
        @influxdb.write_point(@series, data, precision, @retention)
      end

      def precision
        @influxdb.config.time_precision
      end
    end
  end
end
