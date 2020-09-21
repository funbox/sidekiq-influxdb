require 'set'
require 'influxdb'

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

        def call(_worker, msg, queue)
          if @secret_agents.include?(job_class_name(msg))
            yield
            return
          end

          t = @clock.call

          data = {
            tags: {
              class: job_class_name(msg),
              queue: queue,
              event: 'start',
            }.merge(@tags),
            values: {
              jid:           msg['jid'],
              creation_time: msg['created_at'],
              waited:    t - msg['created_at'],
            },
            timestamp: in_correct_precision(t)
          }

          save(data) if @start_events

          begin
            yield
            data[:tags][:event] = 'finish'
          rescue => e
            data[:tags][:event] = 'error'
            data[:tags][:error] = e.class.name
          end

          tt = @clock.call

          data[:values][:worked] = tt - t
          data[:values][:total]  = tt - msg['created_at']
          data[:timestamp] = in_correct_precision(tt)

          save(data)

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
            when 'm'  then (t / 60).to_i
            when 'h'  then (t / 60 / 60).to_i
          end
        end

      end
    end
  end
end
