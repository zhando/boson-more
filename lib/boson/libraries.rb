require 'boson/save'
require 'boson/namespace'
require 'boson/more_util'
# order of library subclasses matters
%w{module file gem require local_file}.each {|e| require "boson/libraries/#{e}_library" }

module Boson
  # == Naming a Library Module
  # Although you can name a library module almost anything, here's the fine print:
  # * A module can have any name if it's the only module in a library.
  # * If there are multiple modules in a file library, the module's name must
  #   be a camelized version of the file's basename
  #   i.e. ~/.boson/commands/ruby_core.rb -> RubyCore.
  # * Although modules are evaluated under the Boson::Commands namespace, Boson
  #   will warn you about creating modules whose name is the same as a top level
  #   class/module. The warning is to encourage users to stay away from
  #   error-prone libraries. Once you introduce such a module, _all_ libraries
  #   assume the nested module over the top level module and the top level
  #   module has to be prefixed with '::' _everywhere_.
  #
  # == Configuration
  # Libraries and their commands can be configured in different ways in this order:
  # * If library is a FileLibrary, commands be configured with a config method
  #   attribute (see Inspector).
  # * If a library has a module, you can set library + command attributes via
  #   the config() callback (see Loader).
  # === Module Callbacks
  # For libraries that have a module i.e. RunnerLibrary, the following class methods
  # are invoked in the order below when loading a library:
  #
  # [*:config*] This method returns a library's hash of attributes as explained by Library.new. This is useful
  #             for distributing libraries with a default configuration. The library attributes specified here
  #             are overridden by ones a user has in their config file except for the :commands attribute, which
  #             is recursively merged together.
  # [*:append_features*] In addition to its normal behavior, this method's return value determines if a
  #                      library is loaded in the current environment. This is useful for libraries that you
  #                      want loaded by default but not in some environments i.e. different ruby versions or
  #                      in irb but not in script/console. Remember to use super when returning true.
  # [*:included*] In addition to its normal behavior, this method should be used to require external libraries.
  #               Although requiring dependencies could be done anywhere in a module, putting dependencies here
  #               are encouraged. By not having dependencies hardcoded in a module, it's possible to analyze
  #               and view a library's commands without having to install and load its dependencies.
  #               If creating commands here, note that conflicts with existing commands won't be detected.
  # [*:after_included*] This method is called after included() to initialize functionality. This is useful for
  #                     libraries that are primarily executing ruby code i.e. defining ruby extensions or
  #                     setting irb features. This method isn't called when indexing a library.
  class Library
    ATTRIBUTES << :gems

    module Libraries
      attr_reader :gems
      def local?
        is_a?(LocalFileLibrary) ||
          (Boson.local_repo && Boson.local_repo.dir == repo_dir)
      end
    end
    include Libraries

    # [*:object_methods*] Boolean which detects any Object/Kernel methods created when loading a library and automatically
    #                     adds them to a library's commands. Default is true.
    module LibrariesLoader
      def detect_additions(options={}, &block)
        options[:object_methods] = @object_methods if !@object_methods.nil?
        super(options, &block).tap do |detected|
          if detected[:gems]
            @gems ||= []
            @gems.concat detected[:gems]
          end
        end
      end

      def module_callbacks
        set_config(@module.config) if @module.respond_to?(:config)
        if @module.respond_to?(:append_features)
          raise AppendFeaturesFalseError unless @module.append_features(Module.new)
        end
        super
      end

      def before_load_commands
        raise(LoaderError, "No module for library #{@name}") unless @module
        if (conflict = Util.top_level_class_conflict(Boson::Commands, @module.to_s))
          warn "Library module '#{@module}' may conflict with top level class/module '#{conflict}' references in"+
            " your libraries. Rename your module to avoid this warning."
        end
        super
      end

      def after_include
        @module.after_included if @module.respond_to?(:after_included) && !@index
        super
      end
    end
    include LibrariesLoader
  end

  # Raised when a library's append_features returns false.
  class AppendFeaturesFalseError < StandardError; end

  class Manager
    module Libraries
      def handle_load_action_error(library, load_method, err)
        if err.is_a? Boson::AppendFeaturesFalseError
          warn "DEBUG: Library #{library} didn't load due to append_features" if Boson.debug
        else
          super
        end
      end

      def before_create_commands(lib)
        super
        if lib.is_a?(FileLibrary) && lib.module
          Inspector.add_method_data_to_library(lib)
        end
      end

      def add_failed_library(library)
        FileLibrary.reset_file_cache(library.to_s)
        super
      end

      def check_for_uncreated_aliases(lib, commands)
        return if lib.is_a?(GemLibrary)
        super
      end
    end
    include Libraries
  end

  class Command
    # hack: have to override
    # Array of array args with optional defaults. Scraped with MethodInspector
    def args(lib=library)
      @args = !@args.nil? ? @args : begin
        if lib
          file_string, meth = file_string_and_method_for_args(lib)
          (file_string && meth && (@file_parsed_args = true) &&
            MethodInspector.scrape_arguments(file_string, meth))
        end || false
      end
    end

    module Libraries
      def file_string_and_method_for_args(lib)
        if !lib.is_a?(ModuleLibrary) && (klass_method = (lib.class_commands || {})[@name])
          klass, meth = klass_method.split(NAMESPACE, 2)
          if (meth_locations = MethodInspector.find_class_method_locations(klass, meth))
            file_string = File.read meth_locations[0]
          end
        elsif File.exists?(lib.library_file || '')
          file_string, meth = FileLibrary.read_library_file(lib.library_file), @name
        end
        [file_string, meth]
      end
    end
    include Libraries
  end

  class MethodInspector
    module Libraries
      def find_class_method_locations(klass, meth)
        if (klass = Util.any_const_get(klass)) && (meth_location = klass.method(meth).source_location) &&
          meth_location[0]
          meth_location
        end
      end
    end
    extend Libraries
  end

  module Scientist
    module Libraries
      def help_options
        {verbose: @global_options[:verbose]}
      end

      def run_help_option(cmd)
        Boson.invoke :usage, cmd.full_name, help_options
      end
    end
    extend Libraries
  end
end
