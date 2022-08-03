module ScoutApm
  module Instruments
    class InfluxDB
      attr_reader :context

      def initialize(context)
        @context = context
        @installed = false
      end

      def logger
        context.logger
      end

      def installed?
        @installed
      end

      def install(prepend:)
        if defined?(::InfluxDB)
          @installed = true

          logger.debug "Instrumenting InfluxDB"

          if prepend
            ::InfluxDB::Client.send(:include, ScoutApm::Tracer)
            ::InfluxDB::HTTP.send(:prepend, InfluxHttpInstrumentationPrepend)
          else
            ::InfluxDB::Client.class_eval do
              include ScoutApm::Tracer
            end

            ::InfluxDB::HTTP.module_eval do
              def do_request_with_scout_instruments(http, req, data = nil)
                params = req.path[1..-1].split("?").last
                cleaned_params = CGI.unescape(params).gsub(/(\s{2,})/,' ')

                self.class.instrument("InfluxDB",
                                      "#{req.path[1..-1].split("?").first.capitalize}",
                                      :desc => cleaned_params,
                                      :ignore_children => true) do
                  do_request_without_scout_instruments(http, req, data)
                end
              end

              alias_method :do_request_without_scout_instruments, :do_request
              alias_method :do_request, :do_request_with_scout_instruments
            end
          end
        end
      end
    end

    module InfluxHttpInstrumentationPrepend
      def do_request(http, req, data = nil)
        params = req.path[1..-1].split("?").last
        cleaned_params = CGI.unescape(params).gsub(/(\s{2,})/,' ')

        self.class.instrument("InfluxDB",
                              "#{req.path[1..-1].split("?").first.capitalize}",
                              :desc => cleaned_params,
                              :ignore_children => true) do
          super(http, req, data)
        end
      end
    end
  end
end
