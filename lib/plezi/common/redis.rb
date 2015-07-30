
module Plezi

	module_function

	# Reviews the Redis connection, sets it up if it's missing and returns the Redis connection.
	#
	# A Redis connection will be automatically created if the `ENV['PL_REDIS_URL']` is set.
	# for example:
	#      ENV['PL_REDIS_URL'] = ENV['REDISCLOUD_URL']`
	# or
	#      ENV['PL_REDIS_URL'] = "redis://username:password@my.host:6379"
	def redis
		return @redis if (@redis_sub_thread && @redis_sub_thread.alive?) && @redis
		return false unless defined?(Redis) && ENV['PL_REDIS_URL']
		@redis_locker ||= Mutex.new
		@redis_locker.synchronize do
			return @redis if (@redis_sub_thread && @redis_sub_thread.alive?) && @redis # repeat the test once syncing is done.
			@redis_uri ||= URI.parse(ENV['PL_REDIS_URL'])
			@redis ||= Redis.new(host: @redis_uri.host, port: @redis_uri.port, password: @redis_uri.password)
			raise "Redis connction failed for: #{ENV['PL_REDIS_URL']}" unless @redis
			@redis_sub_thread = Thread.new do
				begin
				Redis.new(host: @redis_uri.host, port: @redis_uri.port, password: @redis_uri.password).subscribe(Plezi::Settings.redis_channel_name, Plezi::Settings.uuid) do |on|
						on.message do |channel, msg|
							begin
								data = YAML.load(msg)
								next if data[:server] == Plezi::Settings.uuid
								if data[:target]
									GRHttp::Base::WSHandler.unicast data[:target], data
								else
									GRHttp::Base::WSHandler.broadcast data
								end
							rescue => e
								Reactor.error e
							end
						end
					end
				rescue => e
					Reactor.error e
					retry
				end
			end
		end
		@redis
	rescue => e
		Reactor.error e
		false
	end
	alias :redis_connection :redis
end

