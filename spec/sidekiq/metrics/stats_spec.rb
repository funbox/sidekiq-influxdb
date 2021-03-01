require 'influxdb'
require 'sidekiq'

RSpec.describe Sidekiq::Metrics::Stats do

  let(:influxdb_client) { instance_double(InfluxDB::Client, config: config) }
  let(:config) { instance_double(InfluxDB::Config, time_precision: 's') }
  let(:sidekiq_stats) { instance_double(Sidekiq::Stats) }

  before do
    allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats)
    allow(sidekiq_stats).to receive(:instance_variable_get).with(:@stats).and_return({processed: 1})
  end

  it 'writes metrix to InfluxDB client' do
    expect(influxdb_client).to receive(:write_point).with("sidekiq_stats", {
      tags: {stat: :processed},
      values: {size: 1}
    }, 's', nil).once

    described_class.new(influxdb_client: influxdb_client).call
  end

  it 'writes to user-defined series' do
    expect(influxdb_client).to receive(:write_point) do |series, _d, _p, _r|
      expect(series).to eq('some_name')
    end.once

    described_class.new(influxdb_client: influxdb_client, series_name: 'some_name').call
  end

  it 'writes to user-defined retention policy' do
    expect(influxdb_client).to receive(:write_point) do |_s, _d, _p, retention_policy|
      expect(retention_policy).to eq('foo')
    end.once

    described_class.new(influxdb_client: influxdb_client, retention_policy: 'foo').call
  end

  it 'mixes in user-specified tags' do
    expect(influxdb_client).to receive(:write_point) do |_s, data, _p, _r|
      expect(data[:tags][:foo]).to eq('bar')
    end.once

    described_class.new(influxdb_client: influxdb_client, tags: {foo: 'bar'}).call
  end
end
