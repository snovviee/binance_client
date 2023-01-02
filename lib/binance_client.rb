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
      else
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
  Faraday::NestedParamsEncoder.sort_params = false
  Faraday::Request.register_middleware binance_signature: -> { FaradayMiddleware::BinanceSignature }

  attr_reader :api_key, :secret_key

  def initialize(api_key:, secret_key:)
    @api_key = api_key
    @secret_key = secret_key
  end

  def orders(symbol:)
    connection.get('/fapi/v1/allOrders', { symbol: symbol, timestamp: timestamp })
  end

  def place_order(symbol:, side:, type:, time_in_force:, quantity:, price:)
    connection.post('/fapi/v1/order', { symbol: symbol, side: side, type: type, timeInForce: time_in_force, quantity: quantity, price: price, timestamp: timestamp })
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
