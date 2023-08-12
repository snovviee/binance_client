require_relative './environment'
require 'faye/websocket'
require 'byebug'

module BinanceClient
  class WebSocketCoin < Faye::WebSocket::Client

    def initialize(on_open: nil, on_close: nil, on_message: nil, stream: nil, config: Environment.config)
      super config.ws_url + stream, nil, ping: 180

      @request_id_inc = 0

      on :open do |event|
       on_open&.call(event)
      end

      on :message do |event|
       on_message&.call(event)
      end

      on :close do |event|
       on_close&.call(event)
      end
    end
  end
end
