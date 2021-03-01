# Sidekiq-InfluxDB Changelog

## 1.4.0 (2021-03-01)

* Added queue sizes collection class
* Added various Sidekiq internal statistics collection class
* Added Ruby 3.0

## 1.3.0 (2020-09-23)

* Dropped dependency on Bundler and Rake for development. The `gem` command is enough, really.
* Dropped **run-time** dependency on InfluxDB client. It was always possible to pass any object as client anyway.
* Added 100% test coverage with RSpec.
* Fixed and improved the "ignored classes" feature:
  * It now correctly ignores job class names even if they come via ActiveJob (wrapped).
  * It is now possible to pass either an array of class names or a single class name.
  * It is now possible to pass either classes themselves or class names as strings.
* Fixed timestamps for minute and hour precisions

## 1.2.0 (2019-05-03)

* Support all InfluxDB time resolutions (added `ns`, `m`, `h`)

## 1.1.0 (2018-09-03)

* ActiveJob support added

## 1.0.0 (2018-08-08)

* Initial release
