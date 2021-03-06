require 'net/https'
require 'ruby-metrics/version'
require 'ruby-metrics'

module Metrics
  module Reporters
    class Librato
      attr_reader :api_token
      attr_reader :user

      API_URL = "https://metrics-api.librato.com/v1"

      def initialize(options = {})
        @api_token = options[:api_token]
        @user = options[:user] 
        @headers = {
          'User-Agent' => "ruby-metrics #{Metrics::VERSION}"
        }
      end

      def send_data(post_url, post_data)
        url = URI.parse(post_url)
        req = Net::HTTP::Post.new(url.path)
        req.basic_auth @user, @api_token
        @headers.each do |k,v|
          req.add_field(k, v)
        end
        req.set_form_data(post_data)
        https = Net::HTTP.new(url.host, url.port)
        https.use_ssl = true
        #https.set_debug_output($stdout)
            
        https.start do |http| 
          result = http.request(req) 
          case result
            when Net::HTTPCreated
              # OK
              puts "SENT!"
            else
              puts "FAILED TO SEND: #{https.inspect}"
          end
        end
      end

      def report(agent)

        agent.instruments.each do |name, instrument|
          nothing_to_do = false
          measure_time = Time.now.to_i

          case instrument.class.to_s
            when "Metrics::Instruments::Counter"
              value = instrument.to_i
              post_url = "#{API_URL}/counters/#{name}.json" 
              post_data = {:measure_time => measure_time, :value => value.to_i}
              send_data(post_url, post_data)
            when "Metrics::Instruments::Gauge"
              post_url = "#{API_URL}/gauges/#{name}.json"
              if instrument.get.is_a? Hash
                instrument.get.each do |key, value|
                  post_data = {:measure_time => measure_time, :source => key, :value => value}
                  send_data(post_url, post_data)
                end
              else 
                post_data = {:measure_time => measure_time, :value => instrument.get}
                send_data(post_url, post_data)
              end
            when "Metrics::Instruments::Timer"
              post_url = "#{API_URL}/gauges/#{name}.json"
              common_data = {:measure_time => measure_time}

              [:count, :fifteen_minute_rate, :five_minute_rate, :one_minute_rate, :min, :max, :mean].each do |attribute|
                post_data = {:source => attribute, :value => instrument.send(attribute)}.merge(common_data)
                send_data(post_url, post_data)
              end
            else 
              puts "Unhandled instrument"
          end
        end
      end
    end
  end
end
