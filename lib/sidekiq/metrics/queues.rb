require 'sidekiq/api'

module Sidekiq
  module Metrics
    class Queues

      def initialize(
        influxdb_client:,
        series_name: 'sidekiq_queues',
        retention_policy: nil,
        tags: {}
      )
        @influxdb = influxdb_client
        @series = series_name
        @retention = retention_policy
        @tags = tags
      end

      def publish
        queues = Sidekiq::Stats::Queues.new.lengths

        queues.each do |queue, size|
          save(
            tags: {queue: queue}.merge(@tags),
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
