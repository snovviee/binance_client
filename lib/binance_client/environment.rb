require 'ostruct'
require 'json'

module BinanceClient
   class Environment
     class MultipleAssignmentNotAllowed < StandardError; end
     class EnvIsMissing < StandardError
       def message
         'BINANCE_ENV environment variable is not provided'
       end
     end
     class EnvNotAllowed < StandardError
       def message
         "Provided environment is not allowed. Allowed environments are #{ALLOWED_ENVS}"
       end
     end

     ALLOWED_ENVS = [:testnet, :production].freeze

     class << self
       attr_reader :config, :env

       def setup!
         raise MultipleAssignmentNotAllowed if @config

         @env = ENV['BINANCE_ENV']&.downcase&.to_sym
         raise EnvIsMissing unless self.env
         raise EnvNotAllowed unless ALLOWED_ENVS.include? self.env

         @config = OpenStruct.new(env_params)
       end

       private

       def env_params
         path = File.expand_path('../../../data/environments.json', __FILE__)
         file = File.read path
         JSON.parse(file, symbolize_names: true)[self.env]
       end
     end
   end
 end
