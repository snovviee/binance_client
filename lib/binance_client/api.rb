require 'openssl'
require 'faraday'
require_relative './environment'

module FaradayMiddleware
  class BinanceSignature < Faraday::Middleware
    attr_reader :secret_key

    def initialize(app, secret_key)
      super(app)

      @secret_key = secret_key
    end

    def on_request(env)
      if env.url.query
        signature = signature(env.url.query)
        env.url.query += "&signature=#{signature}"
      elsif env.request_body
        signature = signature(env.request_body)
        env.request_body += "&signature=#{signature}"
      end
    end

    private

    def signature(data)
      OpenSSL::HMAC.hexdigest("SHA256", secret_key, data)
    end
  end
end

module BinanceClient
  class API
    Faraday::NestedParamsEncoder.sort_params = false
    Faraday::Request.register_middleware binance_signature: -> { FaradayMiddleware::BinanceSignature }

    attr_reader :api_key, :secret_key, :config

    def initialize(api_key:, secret_key:, config: Environment.config)
      @api_key = api_key
      @secret_key = secret_key
      @config = config
    end

    def orders(symbol:)
      connection.get('/fapi/v1/allOrders', { symbol: symbol, timestamp: timestamp })
    end

    def open_orders(symbol:)
      connection.get('/fapi/v1/openOrders', { symbol: symbol, timestamp: timestamp })
    end

    def place_order(params)
      connection.post('/fapi/v1/order', params.merge(timestamp: timestamp))
    end

    def place_market_order(symbol:, side:, quantity:)
      place_order(symbol: symbol, side: side.to_s.upcase, type: 'MARKET', quantity: quantity)
    end

    def place_limit_order(symbol:, side:, quantity:, price:, goodTillDate: nil)
      params = {
        symbol: symbol, side: side.to_s.upcase, type: 'LIMIT', quantity: quantity, timeInForce: 'GTC', price: price.to_s.to_f
      }
      params.merge!(goodTillDate: timestamp + 660000, timeInForce: 'GTD') if goodTillDate

      place_order(params)
    end

    def place_trailing_stop_market_order(symbol:, side:, quantity:, activation_price:, callback_rate: 2.0)
      params = {
        symbol: symbol,
        side: side.to_s.upcase,
        type: 'TRAILING_STOP_MARKET',
        activationPrice: activation_price,
        callbackRate: callback_rate,
        quantity: quantity
      }

      place_order(params)
    end

    def fetch_balance
      connection.get('/fapi/v2/balance', { timestamp: timestamp })
    end

    def update_leverage(symbol:, leverage:)
      connection.post('/fapi/v1/leverage', { symbol: symbol, leverage: leverage, timestamp: timestamp })
    end

    def start_data_stream
      connection.post('/fapi/v1/listenKey')
    end

    def keepalive_data_stream
      connection.put('/fapi/v1/listenKey')
    end

    def fetch_exchange_info
      connection.get('/fapi/v1/exchangeInfo')
    end

    def user_trades(symbol: ,start_time: nil, end_time: nil)
      params = { symbol: symbol, timestamp: timestamp }
      params.merge!(startTime: start_time, endTime: end_time) if start_time && end_time
      connection.get('/fapi/v1/userTrades', params)
    end

    def trade_download_id(start_time:, end_time:)
      connection.get('/fapi/v1/trade/asyn', { timestamp: timestamp, startTime: start_time, endTime: end_time })
    end

    def trade_download_link(download_id:)
      connection.get('/fapi/v1/trade/asyn/id', { downloadId: download_id, timestamp: timestamp })
    end

    def order_download_id(start_time:, end_time:)
      connection.get('/fapi/v1/order/asyn', { timestamp: timestamp, startTime: start_time, endTime: end_time })
    end

    def order_download_link(download_id:)
      connection.get('/fapi/v1/order/asyn/id', { downloadId: download_id, timestamp: timestamp })
    end

    def order_amendment(symbol:, order_id:)
      params = { symbol: symbol, timestamp: timestamp, orderId: order_id }
      connection.get('/fapi/v1/orderAmendment', params)
    end

    def ticker_24h(symbol: nil)
      params = {}
      params.merge!(symbol: symbol) if symbol
      connection.get('/fapi/v1/ticker/24hr', params)
    end

    def update_margin_type(symbol:, margin_type:) # margin_type "ISOLATED | CROSSED"
      connection.post('/fapi/v1/marginType', { symbol: symbol, marginType: margin_type.to_s.upcase, timestamp: timestamp })
    end

    def position_risk(symbol:)
      connection.get('/fapi/v2/positionRisk', { symbol: symbol, timestamp: timestamp })
    end

    def candlesticks(symbol, interval, limit: 1000, startTime: nil, endTime: nil)
      connection.get('/fapi/v1/klines', symbol: symbol, limit: limit, interval: interval, startTime: startTime, endTime: endTime)
    end

    def cancel_open_orders(symbol:)
      connection.delete('/fapi/v1/allOpenOrders', { symbol: symbol, timestamp: timestamp})
    end

    def place_stop_market_order(symbol:, side:, stop_price:, goodTillDate: nil)
      params = {
        symbol: symbol, side: side.to_s.upcase, type: 'STOP_MARKET', stopPrice: stop_price, closePosition: true
      }
      params.merge!(goodTillDate: timestamp + 1500000, timeInForce: 'GTD') if goodTillDate

      place_order(params)
    end

    def place_take_profit(symbol:, side:, quantity:, stop_price:, price:, reduce_only: false)
      place_order(symbol: symbol, side: side.to_s.upcase, type: 'TAKE_PROFIT', reduceOnly: reduce_only, price: price.to_s.to_f, quantity: quantity, stopPrice: stop_price)
    end

    def place_take_profit_market(symbol:, side:, stop_price:)
      place_order(symbol: symbol, side: side.to_s.upcase, type: 'TAKE_PROFIT_MARKET', stopPrice: stop_price, closePosition: true)
    end

    private

    def connection
      @connection ||= Faraday.new(
        url: config.http_url,
        headers: { 'X-MBX-APIKEY': api_key, 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' }
      ) do |f|
        f.request :url_encoded
        f.request :binance_signature, secret_key
        f.response :logger, ::Logger.new(STDOUT), bodies: false, headers: false
        f.response :json, parser_options: { symbolize_names: true }
      end
    end

    def timestamp
      DateTime.now.strftime('%Q').to_i
    end
  end
end
