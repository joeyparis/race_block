# RaceBlock

A Ruby code block wrapper to help prevent race conditions across multiple threads and even separate servers.

**Disclaimer** This code has been used in production for several years now without incident, but I make no guarantee about the thread-safeness it has. Use at your own risk.

## Concept

### Problem
Multiple servers all have the same cron jobs, but we only want one of them to actually execute the job.

### Solution
Since all the cron jobs should fire at roughly the same time, we can have each one of them generate a unique identifier and "claim" the cron job. We wait 0.5 seconds (or `sleep_delay`) for all of the servers to generate a unique identifier and claim the job by writing their unique identifier to a Redis cache. After the 0.5 seconds, each server checks the Redis cache to see if the stored value matches the one they generated. Only one server will still have a match and successfully claim the job to execute.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'race_block'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install race_block

## Potential Use Cases

The original inspiration behind this gem was running cron jobs across multiple servers to send emails. Since all of the servers would trigger the cron job simultaneously, they would all attempt to send the same email at the same time leading to multiple copies of a single email being sent out. `RaceBlock` solved this problem by ensuring only one instance of `RaceBlock` across all the servers was allowed to work on a single email.

`RaceBlock` could also apply to any cron jobs or block of code that really should only be run once, regardless of which servers tried to initiate it.


## Usage

Any code that you want to be "thread-safe" and ensure is only executing in one location should be placed in a `RaceBlock` with a unique identifying key that will be checked across all instances.

```ruby
RaceBlock.start('unique_key', {}) do
    # Insert code that should only be executed once at a time here...
end
```

### Configuration

|Option|Default|Description|
|------|-------|-----------|
|sleep_delay|0.5|How many seconds the RaceBlock should wait after generating its unique token before it checks if it can execute the RaceBlock. **Important** This value should be longer than the amount of time it takes your server to write to the Redis database. 0.5 seconds has worked for us, but longer  `sleep_delay` values should technically be safer.|
|expire|60|How many seconds the key should be stored for while running. This number should be longer than the length of time the RaceBlock will take to execute once it starts. The key will be deleted 3 seconds after the block completes, regardless of the time left from `expire`.|
|expire_immediately|false|Whether or not the key should expire immediately after block completion, or wait the default 3 seconds.|
|debug|false|Can help debug why a RaceBlock call is running or not running.|
|dsync_tokens|false| **TESTING ONLY** This is purely for testing purposes to simulate inconsistent request times. It should never be used in a production environment.|

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/joeyparis/race_block. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/joeyparis/race_block/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RaceBlock project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/joeyparis/race_block/blob/master/CODE_OF_CONDUCT.md).
