# Sidekiq::InfluxDB

[![Gem Version](https://img.shields.io/gem/v/sidekiq-influxdb.svg)](https://rubygems.org/gems/sidekiq-influxdb)
[![Travis CI](https://img.shields.io/travis/com/funbox/sidekiq-influxdb)](https://travis-ci.com/github/funbox/sidekiq-influxdb)
[![Coveralls](https://img.shields.io/coveralls/funbox/sidekiq-influxdb.svg)](https://coveralls.io/github/funbox/sidekiq-influxdb)

[Sidekiq](https://github.com/mperham/sidekiq/wiki) server middleware
that writes job lifecycle events as points to an [InfluxDB](http://docs.influxdata.com/influxdb/v1.3/) database.
Also includes classes that write global Sidekiq metrics and queue metrics.

## Installation

Add this gem to your application's `Gemfile`:

```bash
bundle add sidekiq-influxdb
```

## Usage

Add included middleware to your application's Sidekiq middleware stack.
The following examples assume that you already have an InfluxDB client object
in the `influxdb` variable.
This will create a middleware with all defaults (suitable for most deployments):

```ruby
# config/initializers/sidekiq.rb

require "sidekiq/middleware/server/influxdb"

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::InfluxDB, influxdb_client: influxdb
  end
end
```

You can customize the middleware by passing more options:

```ruby
# config/initializers/sidekiq.rb

require "sidekiq/middleware/server/influxdb"

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::InfluxDB,
                influxdb_client: influxdb,
                series_name: 'sidekiq_jobs',  # This is the default one.
                retention_policy: 'rp_name',  # In case you want to write metrics to a non-default RP.
                start_events: true,           # Whether or not you want to know when jobs started. See `event` tag description below.
                tags: {application: 'MyApp'}, # Anything you need on top. **Make sure that tag values have low cardinality!**
                except: [UnimportantJob]      # These job classes will be executed without sending any metrics.
  end
end
```

This library assumes that you already have an InfluxDB client object set up the way you like.
It does not try to create one for you.
If that is not the case, you can learn how to create a client
in [InfluxDB client documentation](https://github.com/influxdata/influxdb-ruby#creating-a-client).

**Warning:** This middleware is going to write _a lot_ of metrics.
Set up your InfluxDB client accordingly:
* either set `async: true` in the client's options to use its built-in batching feature,
* or install Telegraf, set up aggregation inside it, and set up InfluxDB client to send metrics to it,
* or both.

When you deploy this code, you will have the following series in your InfluxDB database:

```
> select * from sidekiq_jobs
name: sidekiq_jobs
time                application  class  creation_time      error         event  jid                      queue   total              waited              worked
----                -----------  -----  -------------      -----         -----  ---                      -----   -----              ------              ------
1511707465061000000 MyApp        FooJob 1511707459.0186539               start  51cc82fe75fbeba37b1ff18f default                    6.042410135269165
1511707465061000000 MyApp        FooJob 1511707459.0186539               finish 51cc82fe75fbeba37b1ff18f default 8.046684265136719  6.042410135269165   2.0042741298675537
1511707467068000000 MyApp        BarJob 1511707461.019835                start  3891f241ab84d3aba728822e default                    6.049134016036987
1511707467068000000 MyApp        BarJob 1511707461.019835  NoMethodError error  3891f241ab84d3aba728822e default 8.056788206100464  6.049134016036987   2.0076541900634766
```

Tags (repetitive indexed data; for filtering and grouping by):

* `time` — standard InfluxDB timestamp. Precision of the supplied client is respected.
* `queue` — queue name.
* `class` — job class name. Classes from `except:` keyword argument are skipped (no data is sent to InfluxDB).
* `event` — what happened to the job at the specified `time`: `start`, `finish`, or `error`. If you initialize the middleware with `start_events: false`, there will be no `start` events.
* `error` — if `event=error`, this tag contains the exception class name.
* Your own tags from the initializer.

Values (unique non-indexed data; for aggregation):

* `jid` — unique job ID.
* `creation_time` — job creation time.

Values calculated by this gem (in seconds):

* `waited` — how long the job waited in the `queue` until Sidekiq got around to starting it.
* `worked` — how long it took to perform the job from start to finish or to an exception.
* `total` — how much time passed from job creation to finish. How long it took to do the job, in total.

This schema allows querying various job metrics effectively.

For example, how many reports have been generated in the last day:

```sql
SELECT COUNT(jid) FROM sidekiq_jobs WHERE class = 'ReportGeneration' AND time > now() - 1d
```

How many different jobs were executed with errors in the last day:

```sql
SELECT COUNT(jid) FROM sidekiq_jobs WHERE event = 'error' AND time > now() - 1d GROUP BY class
```

Et cetera.

### Stats and Queues metrics

To collect metrics for task stats and queues, you need to run the following code periodically.
For example, you can use [Clockwork](https://rubygems.org/gems/clockwork) for that.
You can add settings like this to `clock.rb`:

```ruby
require "sidekiq/metrics/stats"
require "sidekiq/metrics/queues"

influx = InfluxDB::Client.new(options)

sidekiq_global_metrics = Sidekiq::Metrics::Stats.new(influxdb_client: influx)
sidekiq_queues_metrics = Sidekiq::Metrics::Queues.new(influxdb_client: influx)

every(1.minute, 'sidekiq_metrics') do
  sidekiq_global_metrics.publish
  sidekiq_queues_metrics.publish
end
```

For stats metrics:

```ruby
require "sidekiq/metrics/stats"

Sidekiq::Metrics::Stats.new(
  influxdb_client: InfluxDB::Client.new(options), # REQUIRED
  series_name: 'sidekiq_stats',                   # optional, default shown
  retention_policy: nil,                          # optional, default nil
  tags: {},                                       # optional, default {}
).publish
```

For queues metrics:

```ruby
require "sidekiq/metrics/queues"

Sidekiq::Metrics::Queues.new(
  influxdb_client: InfluxDB::Client.new(options), # REQUIRED
  series_name: 'sidekiq_queues',                  # optional, default shown
  retention_policy: nil,                          # optional, default nil
  tags: {},                                       # optional, default {}
).publish
```

When you run the code, you will have the following series in your InfluxDB database:

```
> select * from sidekiq_stats
name: sidekiq_stats
time                size     stat
----                ----     ----
1582502419000000000 9999     dead
1582502419000000000 0        workers
1582502419000000000 0        enqueued
1582502419000000000 23020182 processed
```

```
> select * from sidekiq_queues
name: sidekiq_queues
time                queue             size
----                -----             ----
1582502418000000000 default           0
1582502418000000000 queue_name_1      0
```

## Visualization

### Grafana

You can import a ready-made dashboard from [grafana_dashboard.json](grafana_dashboard.json).

## Development

See [Contributing Guidelines](CONTRIBUTING.md).

[![Sponsored by FunBox](https://funbox.ru/badges/sponsored_by_funbox_centered.svg)](https://funbox.ru)
