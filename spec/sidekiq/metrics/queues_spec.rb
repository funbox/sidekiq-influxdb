require 'influxdb'
require 'sidekiq'

RSpec.describe Sidekiq::Metrics::Queues do

  let(:influxdb_client) { instance_double(InfluxDB::Client, config: config) }
  let(:config) { instance_double(InfluxDB::Config, time_precision: 's') }
  let(:sidekiq_queues) { instance_double(Sidekiq::Stats::Queues, lengths: {"default" => 1}) }

  before do
    allow(Sidekiq::Stats::Queues).to receive(:new).and_return(sidekiq_queues)
  end


  it 'writes metrix to InfluxDB client' do
    expect(influxdb_client).to receive(:write_point).with("sidekiq_queues", {
      tags: {queue: 'default'},
      values: {size: 1}
    }, 's', nil).once

    described_class.new(influxdb_client: influxdb_client).publish
  end

  it 'writes to user-defined series' do
    expect(influxdb_client).to receive(:write_point) do |series, _d, _p, _r|
      expect(series).to eq('some_name')
    end.once

    described_class.new(influxdb_client: influxdb_client, series_name: 'some_name').publish
  end

  it 'writes to user-defined retention policy' do
    expect(influxdb_client).to receive(:write_point) do |_s, _d, _p, retention_policy|
      expect(retention_policy).to eq('foo')
    end.once

    described_class.new(influxdb_client: influxdb_client, retention_policy: 'foo').publish
  end

  it 'mixes in user-specified tags' do
    expect(influxdb_client).to receive(:write_point) do |_s, data, _p, _r|
      expect(data[:tags][:foo]).to eq('bar')
    end.once

    described_class.new(influxdb_client: influxdb_client, tags: {foo: 'bar'}).publish
  end
end
