require 'set'

module Sidekiq
  module Middleware
    module Server
      class InfluxDB

        def initialize(
          influxdb_client:,
          series_name: 'sidekiq_jobs',
          retention_policy: nil,
          start_events: true,
          tags: {},
          except: [],
          clock: -> { Time.now.to_f }
        )
          @influxdb = influxdb_client
          @series = series_name
          @retention = retention_policy
          @start_events = start_events
          @tags = tags
          @secret_agents = class_names(except)
          @clock = clock
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
          Set.new([except].flatten.map{|e| class_name(e) })
        end

        def class_name(class_or_name)
          class_or_name.name
        rescue NoMethodError
          class_or_name
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
