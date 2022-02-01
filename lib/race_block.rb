# frozen_string_literal: true

require "securerandom"
require "logger"

require_relative "race_block/version"

# Block for preventing race conditions across multiple threads and instances
module RaceBlock
  class Error < StandardError; end

  # For managing RaceBlock current configuration settings
  class Configuration
    attr_accessor :redis, :expire, :expiration_delay, :sleep_delay

    def initialize
      reset
    end

    def reset
      @expire = 60
      @expiration_delay = 3
      @sleep_delay = 0.5
    end
  end

  class << self
    attr_accessor :configuration
  end

  def self.config
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
    configuration
  end

  def self.client
    config.redis
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.key(key)
    "race_block_#{key}"
  end

  def self.reset(key)
    RaceBlock.client.del(RaceBlock.key(key))
  end

  def self.start(base_key, expire: config.expire, expiration_delay: config.expiration_delay, **args)
    raise("A key must be provided to start a RaceBlock") if base_key.empty?

    key = RaceBlock.key(base_key)

    # Set an expiration for the token if the key is defined but doesn't
    # have an expiration set (happens sometimes if a thread dies early).
    # `-1` means the key is set but does not expire, `-2` means the key is
    # not set
    RaceBlock.client.expire(key, 10) if RaceBlock.client.ttl(key) == -1

    # Token already exists
    return logger.debug("Token already exists") if RaceBlock.client.get(key)

    return unless set_token_and_wait(key, **args)

    RaceBlock.client.expire(key, expire)
    logger.debug("Running block")

    r = yield

    # I have lots of internal debates on whether I should full
    # delete the key here or still let it sit for a few seconds
    RaceBlock.client.expire(key, expiration_delay)

    r
  end

  def self.set_token_and_wait(key, sleep_delay: config.sleep_delay, desync_tokens: 0)
    sleep desync_tokens # Used for testing only
    token = SecureRandom.hex
    RaceBlock.client.set(key, token)
    RaceBlock.client.expire(key, (sleep_delay + 15).round)
    sleep sleep_delay
    # Okay, so I feel like this is pseudo science, but whatever. Our
    # race condition comes from when the same cron job is called by
    # several different server instances at the same time
    # (theoretically) all within the same second (much less really).
    # By waiting a second we can let all the same cron jobs that were
    # called at roughly the exact same time finish their write to the
    # redis cache so that by the time the sleep is over, only one
    # token is still accurate. I'm hesitant to believe this actually
    # works, but I can't find any flaws in the logic at the current
    # moment, and I also believe this is what is keep the EmailQueue
    # stable which seems to have no duplicate sending problems.

    return true if RaceBlock.client.get(key) == token

    # Token out of sync
    logger.debug("Token out of sync")
    false
  end
end
