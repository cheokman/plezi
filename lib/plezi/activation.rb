require 'uri' unless defined?(::URI)
module Plezi
   protected

  @plezi_finalize = nil
  def plezi_finalize
     if @plezi_finalize.nil?
        @plezi_finalize = true
        @plezi_finalize = 1
     end
  end
  @plezi_initialize = nil
  def self.plezi_initialize
     if @plezi_initialize.nil?
        @plezi_initialize = true
        self.hash_proc_4symstr # creates the Proc object used for request params
        @plezi_autostart = true if @plezi_autostart.nil?
        Iodine.patch_rack
        if((ENV['PL_REDIS_URL'.freeze] ||= ENV['REDIS_URL'.freeze]))
          uri = URI(ENV['PL_REDIS_URL'.freeze])
          Iodine.default_pubsub = Iodine::PubSub::RedisEngine.new(uri.host, uri.port, (ENV['PL_REDIS_TIMEOUT'.freeze] || ENV['REDIS_TIMEOUT'.freeze]).to_i, uri.password)
          Iodine.default_pubsub = Iodine::PubSub::Cluster unless Iodine.default_pubsub
        end
        at_exit do
           next if @plezi_autostart == false
           ::Iodine::Rack.app = ::Plezi.app
           ::Iodine.start
        end
     end
     true
  end
end
