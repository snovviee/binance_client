require 'openssl'
require 'faraday'

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

class BinanceClient
  class MarketParamsValidationError < StandardError; end

  Faraday::NestedParamsEncoder.sort_params = false
  Faraday::Request.register_middleware binance_signature: -> { FaradayMiddleware::BinanceSignature }

  attr_reader :api_key, :secret_key

  def initialize(api_key:, secret_key:)
    @api_key = api_key
    @secret_key = secret_key
    BinanceClient.children << self
  end

  def self.children
    @@children ||= Set.new
  end

  def orders(symbol:)
    connection.get('/fapi/v1/allOrders', { symbol: symbol, timestamp: timestamp })
  end

  def place_order(params)
    connection.post('/fapi/v1/order', params.merge(timestamp: timestamp))
  end

  def place_market_order(symbol:, side:, type:, quantity:, time_in_force: nil, price: nil)
    raise MarketParamsValidationError if type == 'MARKET' && (time_in_force || price)

    place_order(symbol: symbol, side: side, type: type, quantity: quantity)
  end

  def balance
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

  private

  def connection
    @connection ||= Faraday.new(
      url: 'https://testnet.binancefuture.com',
      headers: { 'X-MBX-APIKEY': api_key, 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' }
    ) do |f|
      f.request :url_encoded
      f.request :binance_signature, secret_key
      f.response :json, parser_options: { symbolize_names: true }
    end
  end

  def timestamp
    DateTime.now.strftime('%Q').to_i
  end
end
