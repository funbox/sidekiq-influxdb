# Sidekiq::InfluxDB

[![Gem Version](https://img.shields.io/gem/v/sidekiq-influxdb.svg)](https://rubygems.org/gems/sidekiq-influxdb)
[![Travis CI](https://img.shields.io/travis/com/funbox/sidekiq-influxdb)](https://travis-ci.com/github/funbox/sidekiq-influxdb)
[![Coveralls](https://img.shields.io/coveralls/funbox/sidekiq-influxdb.svg)](https://coveralls.io/github/funbox/sidekiq-influxdb)

[Sidekiq](https://github.com/mperham/sidekiq/wiki) middleware that writes job lifecycle events as points to an [InfluxDB](http://docs.influxdata.com/influxdb/v1.3/) database.

## Installation

Add this gem to your application's `Gemfile`:

```bash
bundle add sidekiq-influxdb
```

## Usage

Add included middleware to your application's Sidekiq middleware stack:

```ruby
# config/initializers/sidekiq.rb

require "sidekiq/middleware/server/influxdb"

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Middleware::Server::InfluxDB,
                influxdb_client: InfluxDB::Client.new(options), # REQUIRED
                series_name: 'sidekiq_jobs',                    # optional, default shown
                retention_policy: nil,                          # optional, default nil
                start_events: true,                             # optional, default true
                tags: { application: 'MyApp' },                 # optional, default {}
                except: [UnimportantJob1, UnimportantJob2]      # optional, default []
  end
end
```

You can learn how to create a client in [InfluxDB client documentation](https://github.com/influxdata/influxdb-ruby#creating-a-client).

**Warning:** This middleware is going to write _a lot_ of metrics.
Set up your InfluxDB client accordingly:
* either set `async: true` in the client's options to use its built-in batching feature,
* or install Telegraf, set up aggregation inside it, and set up InfluxDB client to send metrics to it,
* or both.

When you deploy this code, you will start getting the following series in your InfluxDB database:

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

## Visualization

### Grafana

You can import the ready-made dashboard from [grafana_dashboard.json](grafana_dashboard.json).

## Development

* [Sidekiq middleware](https://github.com/mperham/sidekiq/wiki/Middleware)
* [InfluxDB client](https://github.com/influxdata/influxdb-ruby)

After checking out the repo, run `bin/setup` to install dependencies.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at [github.com/funbox/sidekiq-influxdb](https://github.com/funbox/sidekiq-influxdb).
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the `Sidekiq::InfluxDB` project’s codebases, issue trackers,
chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/funbox/sidekiq-influxdb/blob/master/CODE_OF_CONDUCT.md).

[![Sponsored by FunBox](https://funbox.ru/badges/sponsored_by_funbox_centered.svg)](https://funbox.ru)
