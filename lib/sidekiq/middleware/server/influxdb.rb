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
          except: []
        )
          @influxdb = influxdb_client
          @series = series_name
          @retention = retention_policy
          @start_events = start_events
          @tags = tags
          @secret_agents = Set.new(except)
        end

        def call(worker, msg, queue)
          if @secret_agents.include?(worker.class)
            yield
            return
          end
          t = Time.now.to_f
          data = {
            tags: {
              class: worker.class.name,
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
          tt = Time.now.to_f
          data[:values][:worked] = tt - t
          data[:values][:total]  = tt - msg['created_at']
          data[:timestamp] = in_correct_precision(tt)
          save(data)
          raise e if e
        end

        private

        def save(data)
          @influxdb.write_point(@series, data, precision, @retention)
        end

        def precision
          @influxdb.config.time_precision
        end

        def in_correct_precision(t)
          case precision
            # In order of probability in real-world setups
            when 'ms' then (t * 1000).to_i
            when 's'  then  t.to_i
            when 'u'  then (t * 1000000).to_i
          end
        end

      end
    end
  end
end
