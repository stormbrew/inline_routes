class File
	def self.stat_load_path(filename)
		file_stat = nil
		$:.each {|path|
			begin
				file_stat = File.stat("#{path}/#{filename}")
				break
			rescue
			end
		}
		return file_stat || raise(Errno::ENOENT)
	end
end

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
								Thread.current[:inline_routes_mtime_list].push(File.stat_load_path("#{controller}_controller.rb").mtime) if Thread.current[:inline_routes_mtime_list]
								load("#{controller}_controller.rb")
							}
						ensure
							Thread.current[:inline_routes_search_map] = nil
						end
					}
				end
			end
			
			def reload
        if @routes_last_modified && configuration_file
          mtimes = [File.stat(configuration_file).mtime]
					mtimes += ::ActionController::Routing.possible_controllers.collect {|controller| File.stat_load_path("#{controller}_controller.rb").mtime }
					mtime = mtimes.max
          # if it hasn't been changed, then just return
          return if mtime <= @routes_last_modified
          # if it has changed then record the new time and fall to the load! below
          @routes_last_modified = mtime
        end
        load!
			end
			
			alias_method(:inline_routes_original_load_routes!, :load_routes!)
			def load_routes!
				begin
					Thread.current[:inline_routes_mtime_list] = []
					inline_routes_original_load_routes!
					@routes_last_modified = [@routes_last_modified, *Thread.current[:inline_routes_mtime_list]].max
				ensure
					Thread.current[:inline_routes_mtime_list] = nil
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