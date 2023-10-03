require_relative './environment'
require 'faye/websocket'

module BinanceClient
  class WebSocket < Faye::WebSocket::Client
    def initialize(on_open: nil, on_close: nil, on_message: nil, config: Environment.config)
      super config.stream_url, nil, ping: 180

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

    def user_streams(listen_keys)
      subscribe(listen_keys)
    end

    def candleshit
      subscribe("btcusdt@kline_1m")
    end

    private

    def subscribe(streams)
      send({
       method: "SUBSCRIBE",
       params: streams,
       id: request_id,
      }.to_json)
    end

    def request_id
      @request_id_inc += 1
    end
  end
end
