RSpec.describe Sidekiq::Middleware::Server::InfluxDB do
  let(:influxdb_client) { instance_double(InfluxDB::Client, config: config) }
  let(:config) { instance_double(InfluxDB::Config, time_precision: 's') }
  let(:clock) { double(:clock) }
  let(:t) { Time.now.to_f }

  it 'writes metrix to InfluxDB client' do
    expect(influxdb_client).to receive(:write_point).with("sidekiq_jobs", {
      tags: {queue: 'queue', class: 'Worker', event: 'start'},
      values: {jid: 'abc123', creation_time: t, waited: 1.0},
      timestamp: t.to_i + 1
    }, 's', nil).once

    expect(influxdb_client).to receive(:write_point).with("sidekiq_jobs", {
      tags: {queue: 'queue', class: 'Worker', event: 'finish'},
      values: {jid: 'abc123', creation_time: t, waited: 1.0, worked: 2.0, total: 3.0},
      timestamp: t.to_i + 3
    }, 's', nil).once

    allow(clock).to receive(:call).and_return(t + 1, t + 3)

    described_class
      .new(influxdb_client: influxdb_client, clock: clock)
      .call(nil, {'jid' => 'abc123', 'wrapped' => 'Worker', 'created_at' => t}, 'queue') { nil }
  end

  describe 'does not write metrics of ignored job classes' do
    it 'lets through a single class' do
      class Worker; end

      described_class
        .new(influxdb_client: influxdb_client, except: Worker)
        .call(nil, {'wrapped' => 'Worker'}, nil) { nil }
    end

    it 'lets through multiple classes' do
      class Foo; end
      class Bar; end

      middleware = described_class.new(influxdb_client: influxdb_client, except: [Foo, Bar, Foo])
      middleware.call(nil, {'wrapped' => 'Foo'}, nil) { nil }
      middleware.call(nil, {'wrapped' => 'Bar'}, nil) { nil }
    end

    it 'lets through a single class name' do
      described_class
        .new(influxdb_client: influxdb_client, except: 'Worker')
        .call(nil, {'wrapped' => 'Worker'}, nil) { nil }
    end

    it 'lets through multiple class names' do
      middleware = described_class.new(influxdb_client: influxdb_client, except: ['Foo', 'Bar', 'Foo'])
      middleware.call(nil, {'wrapped' => 'Foo'}, nil) { nil }
      middleware.call(nil, {'wrapped' => 'Bar'}, nil) { nil }
    end
  end
end
