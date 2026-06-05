require 'set'

module Sidekiq
  module Middleware
    module Server
      class InfluxDB

        MILLISECONDS_PER_SECOND = 1000.0

        def initialize(options = {})
          @influxdb = options.fetch(:influxdb_client)
          @series = options.fetch(:series_name, 'sidekiq_jobs')
          @retention = options.fetch(:retention_policy, nil)
          @start_events = options.fetch(:start_events, true)
          @tags = options.fetch(:tags, {})
          @secret_agents = class_names(options.fetch(:except, []))
          @clock = options.fetch(:clock, -> { Time.now.to_f })
          @measurement_key = options.fetch(:measurement_key, :values)
        end

        def call(_worker, msg, _queue)
          if @secret_agents.include?(job_class_name(msg))
            yield
            return
          end

          started_at = @clock.call
          waited = started_at - created_at_in_seconds(msg)
          record(started_at, msg, { event: 'start' }, { waited: waited }) if @start_events

          error = nil
          begin
            yield
            tags = { event: 'finish' }
          rescue StandardError => e
            tags = { event: 'error', error: e.class.name }
            error = e
          end

          finished_at = @clock.call
          worked = finished_at - started_at
          record(finished_at, msg, tags, { waited: waited, worked: worked, total: waited + worked })

          raise error if error
        end

        private

        def class_names(except)
          Set.new([except].flatten.map(&:to_s))
        end

        def job_class_name(msg)
          msg['wrapped'] || msg['class']
        end

        def created_at_in_seconds(msg)
          created_at = msg['created_at']
          return created_at unless created_at.is_a?(Integer)

          created_at / MILLISECONDS_PER_SECOND
        end

        def record(t, msg, tags, measurement = {})
          save(
            tags: {
              class: job_class_name(msg),
              queue: msg['queue']
            }.merge(tags).merge(@tags),
            @measurement_key => {
              jid: msg['jid'],
              creation_time: created_at_in_seconds(msg)
            }.merge(measurement),
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
