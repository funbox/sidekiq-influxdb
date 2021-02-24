# Sidekiq-InfluxDB

## Contributing Guidelines

1. All code should be covered by tests. This library is used in high load Sidekiq deployments. Failures are unacceptable.
1. Code should be easy for an average Rubyist to understand.
1. Each pull request should contain changes for a single goal.
1. All logic should be described in the README for users of the library in the most understandable and ready-to-use way.
1. This library uses an existing InfluxDB client object supplied by the user. It does not modify the client in any way.
1. It is better to write a little too many metrics than a little too few. It is good to let the user disable stuff they don't need.
1. It should work in as many Ruby versions as possible. Among those who have not yet come EOL https://www.ruby-lang.org/en/downloads/branches/.  People run a lot of old versions in production. Same for Sidekiq and InfluxDB.
1. RuboCop is not necessary and is not welcome in this project.

Thank you for your contributions!
