require 'helper'
require 'time'
require 'zlib'
require 'stringio'

class HttpFileUploadOutputTest < Test::Unit::TestCase
  # setup/teardown and tests of dummy server defined at the end of this class
  TEST_LISTEN_PORT = 8288

  CONFIG = <<-EOC
    uri http://localhost:#{TEST_LISTEN_PORT}/upload
    buffer_path #{File.dirname(__FILE__)}/tmp
EOC

  def create_driver(conf=CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HttpFileUploadOutput).configure(conf)
  end

  def test_configure
    d = create_driver CONFIG + <<-CONF
      filename myname.log
      param_name content
      user_agent testing now
      headers    {"My-Header": "MyValue", "My-Header-2": "My Custom Value"}
      parameters {"username": "satoshi tagomori"}
CONF
    assert_equal "myname.log", d.instance.filename
    assert_equal "content", d.instance.param_name
    assert_equal "testing now", d.instance.user_agent
    assert_equal "MyValue", d.instance.headers['My-Header']
    assert_equal "My Custom Value", d.instance.headers['My-Header-2']
    assert_equal "satoshi tagomori", d.instance.parameters['username']
    assert_nil d.instance.compress

    assert d.instance.instance_eval{ @formatter }.is_a? Fluent::TextFormatter::JSONFormatter
  end

  def test_emit_default_config
    d = create_driver
    time = Time.parse("2016-02-24 16:20:30 -0800").to_i
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    assert @headers['user-agent'].start_with?('fluent-plugin-http_file_upload')
    assert @params['file']
    assert { @params['file'].name =~ /^data\.\d{4}(-\d{2}){5}$/ }
    assert_equal 'application/octet-stream', @params['file'].type
    rows = @params['file'].body.each_line.map{|line| JSON.parse(line)}
    assert_equal row0, rows[0]
    assert_equal row1, rows[1]
    assert_equal row2, rows[2]
  end

  def test_emit_with_timekey
    d = create_driver CONFIG + <<-CONF
      include_time_key true
      time_format %m/%d/%Y %H:%M:%s
      utc true
CONF
    t = Time.parse("2016-02-24 16:20:30 -0800")
    time = t.to_i
    time_str = t.utc.strftime('%m/%d/%Y %H:%M:%s')
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    rows = @params['file'].body.each_line.map{|line| JSON.parse(line)}
    assert_equal row0.merge({'time' => time_str}), rows[0]
    assert_equal row1.merge({'time' => time_str}), rows[1]
    assert_equal row2.merge({'time' => time_str}), rows[2]
  end

  def test_emit_as_tsv
    d = create_driver CONFIG + <<-CONF
      include_time_key true
      time_format %m/%d/%Y %H:%M:%s
      utc true
      format csv
      delimiter TAB
      force_quotes false
      fields time,f1,f2,f3
CONF
    t = Time.parse("2016-02-24 16:20:30 -0800")
    time = t.to_i
    time_str = t.utc.strftime('%m/%d/%Y %H:%M:%s')
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    rows = @params['file'].body.each_line.map{|line| line.chomp}
    assert_equal "#{time_str}\tdata\tvalue2\tvalue3", rows[0]
    assert_equal "#{time_str}\tdata\tvalue4\tvalue4", rows[1]
    assert_equal "#{time_str}\tdata2\tvalue5\tvalue6", rows[2]
  end

  def test_emit_with_custom_header
    d = create_driver CONFIG + <<-CONF
      include_time_key true
      time_format %m/%d/%Y %H:%M:%s
      utc true
      format csv
      delimiter TAB
      force_quotes false
      fields time,f1,f2,f3
      headers {"Authorization": "Basic A0AaaAAaaAAaAaAAA0Aaa0AaaaA="}
CONF
    t = Time.parse("2016-02-24 16:20:30 -0800")
    time = t.to_i
    time_str = t.utc.strftime('%m/%d/%Y %H:%M:%s')
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    assert_equal 'Basic A0AaaAAaaAAaAaAAA0Aaa0AaaaA=', @headers['authorization']
  end

  def test_eit_with_custom_parameter
    d = create_driver CONFIG + <<-CONF
      include_time_key true
      time_format %m/%d/%Y %H:%M:%s
      utc true
      format csv
      delimiter TAB
      force_quotes false
      fields time,f1,f2,f3
      headers {"Authorization": "Basic A0AaaAAaaAAaAaAAA0Aaa0AaaaA="}
      parameters {"name": "my name", "email": "user@fluentd.org"}
CONF
    t = Time.parse("2016-02-24 16:20:30 -0800")
    time = t.to_i
    time_str = t.utc.strftime('%m/%d/%Y %H:%M:%s')
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    assert_equal "my name", @params['name']
    assert_equal "user@fluentd.org", @params['email']
  end

  def test_emit_with_compression
    d = create_driver CONFIG + <<-CONF
      compress gzip
CONF
    time = Time.parse("2016-02-24 16:20:30 -0800").to_i
    row0 = {'f1' => 'data', 'f2' => 'value2', 'f3' => 'value3'}
    row1 = {'f1' => 'data', 'f2' => 'value4', 'f3' => 'value4'}
    row2 = {'f1' => 'data2', 'f2' => 'value5', 'f3' => 'value6'}
    d.emit(row0, time)
    d.emit(row1, time)
    d.emit(row2, time)
    d.run
    assert @headers['user-agent'].start_with?('fluent-plugin-http_file_upload')
    assert @params['file']
    assert { @params['file'].name =~ /^data\.\d{4}(-\d{2}){5}\.gz$/ }
    assert_equal 'application/octet-stream', @params['file'].type

    io = StringIO.new(@params['file'].body)
    Zlib::GzipReader.wrap(io) do |gz|
      rows = gz.each_line.map{|line| JSON.parse(line)}
      assert_equal row0, rows[0]
      assert_equal row1, rows[1]
      assert_equal row2, rows[2]
    end
  end

  class FileEntry
    attr_reader :name, :type, :body
    def initialize(filename, content_type, content_body)
      @name = filename
      @type = content_type
      @body = content_body
    end
  end

  def setup
    Fluent::Test.setup
    @headers = {}
    @body = nil
    @content_type = nil
    @boundary = nil
    @params = {}
    @dummy_server_thread = Thread.new do
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => TEST_LISTEN_PORT})
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => TEST_LISTEN_PORT, :Logger => logger, :AccessLog => []})
            end
      begin
        srv.mount_proc('/upload') do |req, res|
          unless req.request_method == 'POST'
            res.status = 405
            res.body = 'request method mismatch'
            next
          end

          @headers = req.dup
          @body = req.body
          @content_type = @headers['content-type']
          begin
            if @content_type && @content_type.start_with?('multipart/form-data;')
              @boundary = @content_type.split(/\s*;\s*/).select{|part| part.start_with?("boundary=")}.map{|b| b.sub("boundary=","")}.first
            end
            if @boundary
              parts = @body.split(/--#{@boundary}(?:--)?\r\n/).map(&:chomp)
              parts.each do |part|
                next if part.empty?
                raw_header, content = part.split("\r\n\r\n", 2)
                header = WEBrick::HTTPUtils.parse_header(raw_header)
                disposition = header['content-disposition'].first
                if disposition && disposition.start_with?("form-data;")
                  attrs = Hash[
                    disposition
                      .split(/\s*;\s*/)
                      .map{|kv| k,v=kv.split('=', 2); v ? [k, v[1..-2].gsub('\\\\', '\\').gsub('\"', '"')] : [k,k]}
                  ]
                  if attrs['name']
                    if disposition.include?('; filename=')
                      @params[attrs['name']] = FileEntry.new(attrs['filename'], header['content-type'].first, content)
                    else
                      @params[attrs['name']] = content
                    end
                  end
                end
              end
            end
          rescue => e
            p e
          end
          res.status = 200
        end
        srv.mount_proc('/'){|req, res| req.status = 200 }
        srv.start
      ensure
        srv.shutdown
      end
    end

    # to wait until dummy server starts to respond for requests
    require 'thread'
    cv = ConditionVariable.new
    watcher = Thread.new do
      connected = false
      while not connected
        begin
          HTTPClient.new.get("http://localhost:#{TEST_LISTEN_PORT}/")
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    end
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    }
  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end

  def test_dummy_server
    d = create_driver
    d.instance.uri =~ /http:\/\/([.:a-z0-9]+)\//
    server = $1
    host = server.split(':')[0]
    port = server.split(':')[1].to_i
    client = HTTPClient.new

    header = {'User-Agent' => "testing dummy server", 'Authorization' => 'Basic Y2RzdGVzdGVyOkNEU3Rlc3RlcjE='}
    content = "aaa bbb xxx yyy zzz"
    client.post(d.instance.uri, content, header)

    assert_equal content, @body
    assert_equal "testing dummy server", @headers['user-agent']
    assert_equal "Basic Y2RzdGVzdGVyOkNEU3Rlc3RlcjE=", @headers['authorization']
  end
end
