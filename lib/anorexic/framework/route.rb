module Anorexic
	#####
	# this class holds the route and matching logic that will normally be used for HTTP handling
	# it is used internally and documentation is present for development and edge users.
	class Route
		# the Regexp that will be used to match the request.
		attr_reader :path
		# the controller that answers the request on this path (if exists).
		attr_reader :controller
		# the proc that answers the request on this path (if exists).
		attr_reader :proc

		def on_request request
			fill_paramaters = match request.path
			return false unless fill_paramaters
			fill_paramaters.each {|k,v| HTTP.add_param_to_hash k, v, request.params }
			response = HTTPResponse.new request
			if controller
				ret = controller.new(request, response)._route_path_to_methods_and_set_the_response_
				response.try_finish if ret
				return ret
			elsif proc
				ret = proc.call(request, response)
				response.try_finish if ret
				return ret
			elsif controller == false
				request.path = path.match(request.path).to_a.last
			end
			return false
		end

		# the initialize method accepts a Regexp or a String and creates the path object.
		#
		# Regexp paths will be left unchanged
		#
		# a string can be either a simple string `"/users"` or a string with paramaters:
		# `"/static/:required/(:optional)/(:optional_with_format){[\d]*}/:optional_2"`
		def initialize path, controller, &block
			@path_sections = false
			initialize_path path
			initialize_controller controller, block
		end
		def initialize_controller controller, block
			@controller, @proc = controller, block
			if controller.is_a?(Class)
				# add controller magic
				if controller.methods(false).include?(:on_message)
				else
					@controller = self.class.make_controller_magic controller
				end
			end
		end
		def initialize_path path
			@fill_paramaters = {}
			if path.is_a? Regexp
				@path = path
			elsif path.is_a? String
				if path == '*'
					@path = /.*/
				else
					param_num = 0
					section_search = "(\/[^\/]*)"
					optional_section_search = "(\/[^\/]*)?"
					@path = '^'
					path = path.gsub(/(^\/)|(\/$)/, '').split '/'
					@path_sections = path.length
					path.each do |section|
						if section == '*'
							# create catch all
							@path << "(.*)"
							# finish
							@path = /#{@path}$/
							return

						# check for routes formatted: /:paramater - required paramaters
						elsif section.match /^\:([\w]*)$/
							#create a simple section catcher
						 	@path << section_search
						 	# add paramater recognition value
						 	@fill_paramaters[param_num += 1] = section.match(/^\:([\w]*)$/)[1]


						# check for routes formatted: /(:paramater) - optional paramaters
						elsif section.match /^\(\:([\w]*)\)$/
							#create a optional section catcher
						 	@path << optional_section_search
						 	# add paramater recognition value
						 	@fill_paramaters[param_num += 1] = section.match(/^\(\:([\w]*)\)$/)[1]

						# check for routes formatted: /(:paramater){options} - optional paramaters
						elsif section.match /^\(\:([\w]*)\)\{(.*)\}$/
							#create a optional section catcher
						 	@path << (  "(\/(" +  section.match(/^\(\:([\w]*)\)\{(.*)\}$/)[2] + "))?"  )
						 	# add paramater recognition value
						 	@fill_paramaters[param_num += 1] = section.match(/^\(\:([\w]*)\)\{(.*)\}$/)[1]
						 	param_num += 1 # we are using two spaces

						else
							@path << "\/"
							@path << section
						end
					end
					if @fill_paramaters.empty?
						@path << optional_section_search
						@fill_paramaters[param_num += 1] = "id"
					end
					@path = /#{@path}$/
				end
			else
				raise "Path cannot be initialized - path must be either a string or a regular experssion."
			end	
			return
		end

		# this performs the match and assigns the paramaters, if required.
		def match path
			m = @path.match path
			return false unless m
			hash = {}
			@fill_paramaters.each { |k, v|  hash[v] = m[k][1..-1] if m[k] && m[k] != '/' }
			hash
		end

		###########
		## class magic methods

		protected

		# injects some magic to the controller
		#
		# adds the `redirect_to` and `send_data` methods to the controller class, as well as the properties:
		# env:: the env recieved by the Rack server.
		# params:: the request's paramaters.
		# cookies:: the request's cookies.
		# flash:: an amazing Hash object that sets temporary cookies for one request only - greate for saving data between redirect calls.
		#
		def self.make_controller_magic(controller)
			new_class_name = "AnorexicMagicController_#{controller.name.gsub /[\:\-]/, '_'}"
			return Module.const_get new_class_name if Module.const_defined? new_class_name
			ret = Class.new(controller) do
				include Anorexic::ControllerMagic

				def initialize request, response
					@request, @params, @flash = request, request.params, response.flash
					@response = response
					# @response["content-type"] ||= ::Anorexic.default_content_type

					# create magical cookies
					@cookies = request.cookies
					@cookies.set_controller self
					super()
				end

				def _route_path_to_methods_and_set_the_response_
					return false if self.methods.include?(:before) && before == false
					got_from_action = requested_method
					got_from_action = self.method(got_from_action).call if got_from_action

					unless got_from_action
						return false
					end

					return false if self.methods.include?(:after) && after == false
					if got_from_action.is_a?(String)
						response << got_from_action
					end
					return true
				end
			end
			Object.const_set(new_class_name, ret)
			ret
		end

	end

end