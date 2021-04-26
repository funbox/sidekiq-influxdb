require 'set'

module Sidekiq
  module Middleware
    module Server
      class InfluxDB

        def initialize(options = {})
          @influxdb = options.fetch(:influxdb_client)
          @series = options.fetch(:series_name, 'sidekiq_jobs')
          @retention = options.fetch(:retention_policy, nil)
          @start_events = options.fetch(:start_events, true)
          @tags = options.fetch(:tags, {})
          @secret_agents = class_names(options.fetch(:except, []))
          @clock = options.fetch(:clock, -> { Time.now.to_f })
        end

        def call(_worker, msg, _queue)
          if @secret_agents.include?(job_class_name(msg))
            yield
            return
          end

          started_at = @clock.call
          waited = started_at - msg['created_at']
          record(started_at, msg, {event: 'start'}, {waited: waited}) if @start_events

          begin
            yield
            tags = {event: 'finish'}
          rescue => e
            tags = {event: 'error', error: e.class.name}
          end

          finished_at = @clock.call
          worked = finished_at - started_at
          record(finished_at, msg, tags, {waited: waited, worked: worked, total: waited + worked})

          raise e if e
        end

        private

        def class_names(except)
          Set.new([except].flatten.map(&:to_s))
        end

        def job_class_name(msg)
          msg['wrapped'] || msg['class']
        end

        def record(t, msg, tags, values = {})
          save(
            tags: {
              class: job_class_name(msg),
              queue: msg['queue']
            }.merge(tags).merge(@tags),
            values: {
              jid: msg['jid'],
              creation_time: msg['created_at']
            }.merge(values),
            timestamp: in_correct_precision(t)
          )
        end

        def save(data)
          @influxdb.write_point(@series, data, precision, @retention)
        end

        def precision
          @influxdb.config.time_precision
        end

        def in_correct_precision(t)
          case precision
            # In order of probability in real-world setups
            when 'ms' then (t * 1_000).to_i
            when 's'  then  t.to_i
            when 'u'  then (t * 1_000_000).to_i
            when 'ns' then (t * 1_000_000_000).to_i
            when 'm'  then (t / 60).to_i * 60
            when 'h'  then (t / 60 / 60).to_i * 60 * 60
          end
        end

      end
    end
  end
end
