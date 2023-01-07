require 'ostruct'
require 'json'

module BinanceClient
   class Environment
     class EnvNotAllowed < StandardError; end
     class MultipleAssignmentNotAllowed < StandardError; end
     class EnvIsMissing < StandardError; end

     ALLOWED_ENVS = [:testnet].freeze

     class << self
       attr_reader :config, :env

       def setup!(env)
         @env = env&.downcase&.to_sym

         raise MultipleAssignmentNotAllowed if @config
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
