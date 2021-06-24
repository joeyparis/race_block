# frozen_string_literal: true

require "thwait"

RSpec::Matchers.define :one_of do |arr|
  match { |actual| arr.include?(actual) }
end

# RSpec::Matchers.define :starts_with do |str|
#   match { |actual| actual.start_with?(str) }
# end

RSpec.describe RaceBlock do
  before do
    ENV["RACK_ENV"] = "test"
  end

  before(:each) do |example|
    @key = example.description
  end

  after(:each) do
    RaceBlock.reset(@key)
  end

  it "has a version number" do
    expect(RaceBlock::VERSION).not_to be nil
  end

  it "pings redis" do
    expect(RaceBlock.client.ping).to eq("PONG")
  end

  it "writes to redis" do
    time = Time.now.to_s
    expect(RaceBlock.client.set("writes to redis", time)).to eq("OK")
  end

  it "handles a failed redis connection", reload: true do
    expect(RaceBlock.logger).to receive(:error)
    ENV["REDIS_HOST"] = "google.com"
    RaceBlock.client(reload: true)
    # Reset so redis is working again
    ENV["REDIS_HOST"] = nil
    RaceBlock.client(reload: true)
  end

  it "reads what it wrote from redis" do
    time = Time.now.to_s
    RaceBlock.client.set("reads what it wrote from redis", time)
    expect(RaceBlock.client.get("reads what it wrote from redis")).to eq(time)
  end

  it "has a consistent key" do
    time = Time.now.to_s
    expect(RaceBlock.key(time)).to eq("race_block_#{time}")
  end

  it "fails if no key is provided" do
    expect { RaceBlock.start("") }.to raise_error("A key must be provided to start a RaceBlock")
  end

  it "returns it's yield and expire immediately" do
    expect(RaceBlock.logger).to receive(:debug).with("Running block").once
    returned_value = RaceBlock.start(@key, **{ expiration_delay: 0 }) do
      "yield_returned"
    end

    expect(returned_value).to eq("yield_returned")
  end

  it "only runs once" do
    dbl = double("dbl")
    expect(dbl).to receive(:log).once
    expect(RaceBlock.logger).to receive(:debug).with("Running block").once
    expect(RaceBlock.logger).to receive(:debug).with(one_of(["Token already exists",
                                                             "Token out of sync"])).exactly(2).times
    threads = (0..2).map do
      Thread.start do
        puts (RaceBlock.start(@key) do
          dbl.log
        end)
      end
    end
    ThreadsWait.all_waits threads
  end

  it "doesn't always run the first call" do
    dbl = double("dbl")
    expect(dbl).to receive(:log).once
    allow(RaceBlock.logger).to receive(:debug).with("Token already exists")
    expect(RaceBlock.logger).to receive(:debug).with("Running block").once
    expect(RaceBlock.logger).to receive(:debug).with("Token out of sync").at_least(1).times
    # ENV["DESYNC_TOKENS"] = "true"
    threads = (0..99).map do
      Thread.start do
        RaceBlock.start(@key, **{ sleep_delay: 5, expiration_delay: 10, desync_tokens: rand(0.0..5) }) { dbl.log }
      end
    end
    ThreadsWait.all_waits threads
    # ENV.delete("DESYNC_TOKENS")
  end

  # TODO: Add test to make sure token expires if something goes wrong
end
