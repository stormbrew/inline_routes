module InlineRoutes
	class Mapper
		attr :real_mapper
		attr :current_controller
		
		def initialize(map, current_controller)
			@real_mapper = map
			@current_controller = current_controller
		end
		
		def method_missing(*funcargs)
			@real_mapper.send(*funcargs)
		end
		
		def connect(path, options = {})
			options[:controller] = current_controller if (!options[:controller])
			@real_mapper.connect(path, options)
		end
		def root(options = {})
			options[:controller] = current_controller if (!options[:controller])
			@real_mapper.root(options)
		end
		def named_route(name, path, options = {})
			options[:controller] = current_controller if (!options[:controller])
			@real_mapper.named_route(name, path, options)
		end
		
		def inline_routes()
			raise "Cannot nest inline_routes calls."
		end
	end
end

module ::ActionController
	module Routing
		class RouteSet
			class Mapper
				def inline_routes()
					# get a list of possible controllers
					controllers = ::ActionController::Routing.possible_controllers
					controllers.each {|controller|
						# Set a mode flag in a TLS variable to indicate we're loading routes.
						begin
							Thread.current[:inline_routes_search_map] = InlineRoutes::Mapper.new(self, controller)
							catch(:done_inline_routes) {
								load("#{controller}_controller.rb")
							}
						ensure
							Thread.current[:inline_routes_search_map] = nil
						end
					}
				end
			end
			
			def inline_draw(&block)
				# Do inline routes if the tls block is set
				if (Thread.current[:inline_routes_search_map])
					block.call(Thread.current[:inline_routes_search_map])
					throw :done_inline_routes # This is only a partial load.
				end
			end
		end
	end
end