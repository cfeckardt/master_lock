require 'spec_helper'

RSpec.describe MasterLock, redis: true do
  before do
    MasterLock.configure do |config|
      config.redis = redis
      config.sleep_time = 0.025
    end
    MasterLock.start
  end

  it "does not allow a lock to be acquired multiple times" do
    MasterLock.synchronize('test') do
      expect { MasterLock.synchronize('test', acquire_timeout: 0) {} }
        .to raise_error(MasterLock::LockNotAcquiredError)
    end
  end

  it "allows a lock to be acquired after it was released" do
    MasterLock.synchronize('test') {}
    expect { MasterLock.synchronize('test', acquire_timeout: 0) {} }
      .to_not raise_error
  end

  it "extends held locks automatically" do
    MasterLock.synchronize('test', ttl: 1, extend_interval: 0.05) do
      sleep 0.2
      expect { MasterLock.synchronize('test', acquire_timeout: 0) {} }
        .to raise_error(MasterLock::LockNotAcquiredError)
    end
  end

  describe ".synchronize" do
    it "returns the result of the block" do
      result = MasterLock.synchronize('test') { 42 }
      expect(result).to eq(42)
    end

    it "raises an ArgumentError when ttl is less than extend_interval" do
      expect { MasterLock.synchronize('test', ttl: 1, extend_interval: 2) }
        .to raise_error(ArgumentError)
    end

    it "raises an ArgumentError when ttl is less than extend_interval" do
      expect { MasterLock.synchronize('test', extend_interval: -1) }
        .to raise_error(ArgumentError)
    end

    context "when the :if option is false" do
      it "does not obtain the lock" do
        MasterLock.synchronize('test_lock', if: false, acquire_timeout: 0) do
          expect { MasterLock.synchronize('test_lock', if: true, acquire_timeout: 0) {} }
            .to_not raise_error
        end
      end

      it "returns the result of the block" do
        result = MasterLock.synchronize('test_lock', if: false) { 42 }
        expect(result).to eq(42)
      end
    end
  end
end
