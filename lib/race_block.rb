# frozen_string_literal: true

require 'securerandom'
require 'logger'
require 'redis'
require_relative "race_block/version"

module RaceBlock
  class Error < StandardError; end
  
  def self.client(reload=false)
    if @redis.nil? || reload
      @redis = Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'])

      begin
          @redis.ping
      rescue Redis::CannotConnectError => e
          RaceBlock.logger.error e
      end
    end
    @redis
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def self.key key
    "race_block_#{key}"
  end

  def self.reset key
    RaceBlock.client.del(RaceBlock.key(key))
  end

  def self.start key, sleep_delay: 0.5, expire: 60, expire_immediately: false, debug: false, desync_tokens: false
    raise('A key must be provided to start a RaceBlock') if key.nil? || key.empty?

    @key = RaceBlock.key(key)

    # Set an expiration for the token if the key is defined but doesn't
    # have an expiration set (happens sometimes if a thread dies early).
    # `-1` means the key is set but does not expire, `-2` means the key is
    # not set
    RaceBlock.client.expire( @key, 10 ) if -1 == RaceBlock.client.ttl( @key )

    if !RaceBlock.client.get( @key )
      sleep rand(0.0..sleep_delay) if desync_tokens
      token = SecureRandom.hex
      RaceBlock.client.set( @key, token)
      RaceBlock.client.expire(@key, 15)
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
      if RaceBlock.client.get( @key ) == token
        RaceBlock.client.expire( @key, expire.is_a?(Integer) ? expire : 60)
        logger.info("Running block") if debug

        r = yield

        # I have lots of internal debates on whether I should full
        # delete the key here or still let it sit for a few seconds
        RaceBlock.client.expire(@key, desync_tokens ? 10 : 3)

        RaceBlock.client.del(@key) if expire_immediately

        return r
      else
        # Token out of sync
        logger.info('Token out of sync') if debug
      end
    else
      # Token already exists
      logger.info('Token already exists') if debug
    end
  end

end
