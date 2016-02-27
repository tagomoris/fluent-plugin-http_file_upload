require 'fluent/output'
require 'fluent/mixin'

require 'tempfile'
require 'openssl'
require 'uri'
require 'httpclient'

module Fluent
  class FileBufferChunk < BufferChunk
    # to pass file object to httpclient for multipart upload
    def to_io
      @file
    end
  end

  class HttpFileUploadOutput < BufferedOutput
    Plugin.register_output('http_file_upload', self)

    include Fluent::SetTimeKeyMixin

    config_set_default :buffer_type, "file"

    config_param :uri, :string, desc: "Full URI for http upload endpoint for POST requests"

    config_param :param_name, :string, default: "file", desc: "Parameter name which contains uploaded file content"
    config_param :user_agent, :string, default: "fluent-plugin-http_file_upload", desc: "User-Agent header content"
    config_param :headers,    :hash, default: {}, desc: "Additional header fields for requests"
    config_param :parameters, :hash, default: {}, desc: "Additional form parameters (key-value pairs) for requests"

    config_param :ssl_verify_mode, default: OpenSSL::SSL::VERIFY_PEER do |value|
      case value.strip
      when "none" then OpenSSL::SSL::VERIFY_NONE
      when "peer" then OpenSSL::SSL::VERIFY_PEER
      else
        raise Fluent::ConfigError, "Unknown ssl_verify_mode '#{value.strip}' [none, peer]"
      end
    end

    desc "Filename in upload requests, formats for strftime available"
    config_param :filename, :string, default: "data.%Y-%m-%d-%M-%H-%S"

    config_param :format,   :string, default: "json", desc: "How to format records in uploaded files"

    SUPPORTED_COMPRESSION_TYPES = ['gzip']
    config_param :compress, default: nil do |val|
      unless SUPPORTED_COMPRESSION_TYPES.include?(val)
        raise Fluent::ConfigError, "unsupported compression type: #{val}"
      end
      val
    end

    def configure(conf)
      super

      @formatter = Plugin.new_formatter(@format)
      @formatter.configure(conf)
      @client = HTTPClient.new(agent_name: @user_agent, default_header: @headers)
      # @client.debug_dev = $stderr
      if @uri.start_with?("https://")
        @client.ssl_config.verify_mode = @ssl_verify_mode
      end

      case @compress
      when 'gzip'
        raise Fluent::ConfigError, "gzip command unavailable" unless system('gzip -h > /dev/null 2>&1')
      end
    end

    def format(tag, time, record)
      @formatter.format(tag, time, record)
    end

    def write(chunk)
      case @compress
      when 'gzip'
        write_gzip(chunk)
      else
        write_plain(chunk)
      end
    end

    def write_plain(chunk)
      filename = Time.now.strftime(@filename)
      chunk.open do |io|
        io.singleton_class.class_eval{ define_method(:path){ filename } }
        postdata = { @param_name => io }
        unless @parameters.empty?
          postdata = @parameters.merge(postdata)
        end
        @client.post(@uri, postdata)
      end
    end

    def write_gzip(chunk)
      filename = Time.now.strftime(@filename) + '.gz'
      path = if chunk.respond_to?(:path)
               chunk.path
             else
               w = Tempfile.new('chunk-gzip-temp-http_file_upload')
               chunk.write_to(w)
               w.close
               w.path
             end
      tmp = Tempfile.new('gzip-temp-http_file_upload')
      tmp.close # file will be removed after GC
      res = system "gzip -c #{path} > #{tmp.path}"
      unless res
        log.warn "failed to execute gzip command: exit code '#{$?}'"
      end
      tmp.open
      tmp.singleton_class.class_eval{ define_method(:path){ filename } }
      postdata = { @param_name => tmp }
      unless @parameters.empty?
        postdata = @parameters.merge(postdata)
      end
      @client.post(@uri, postdata)
      tmp.close
    end
  end
end
