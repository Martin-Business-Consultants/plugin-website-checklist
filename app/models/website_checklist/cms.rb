require "net/http"

module WebsiteChecklist
  # A LibrePublish CMS's API, read with a token (Bearer). Only reads; a failure is a Cms::Error
  # saying what went wrong in words a person can act on.
  class Cms
    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        super(message)
        @status = status
      end
    end

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # How a request goes out: ->(uri, token) { [status, body] }. Tests put a stand-in here.
    class_attribute :transport, default: ->(uri, token) {
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/json"
        response = http.request(request)
        [ response.code.to_i, response.body ]
      end
    }

    attr_reader :base_url

    def initialize(base_url, token)
      @base_url = base_url.to_s.chomp("/")
      @token = token
    end

    # The parsed JSON at `path` ("/api/forms?status=published").
    def get(path)
      status, body = transport.call(URI.parse(base_url + path), @token)
      case status
      when 200..299 then JSON.parse(body.presence || "{}")
      when 401 then raise Error.new("the CMS didn't accept the token", status: status)
      when 403 then raise Error.new("the token isn't allowed to read it", status: status)
      when 404 then raise Error.new("not found", status: status)
      else raise Error.new("the CMS answered #{status}", status: status)
      end
    rescue JSON::ParserError
      raise Error.new("the CMS didn't answer with JSON")
    rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => error
      raise Error.new("couldn't reach #{base_url} (#{error.class.name.demodulize})")
    end

    def admin_url(path) = base_url + path
  end
end
