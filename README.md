# fluent-plugin-http_file_upload

[Fluentd](http://fluentd.org) output plugin to send fluentd messages to web servers as file uploading.

This plugin works for web servers, which provides file uploading feature from web browsers as `multipart/form-data`. Files will be generated for each flushing, and uploaded to servers. Filename can contain uploaded timestamp using time formatter.

## Installation

Install with gem or fluent-gem command like these:

```
 # native gem
 $ gem install fluent-plugin-http_file_upload
 
 # fluentd gem
 $ fluent-gem install fluent-plugin-http_file_upload
```

## Configuration

This plugin works well with default configuration with JSON-per-line formatting and uploading with parameter name `file`. This plugin's default buffer is file buffer, so that `buffer_path` configuration parameter is required.

```apache
<match upload.**>
  @type http_file_upload
  buffer_path /path/to/buffer
  uri  http://my.server.example.com/upload
</match>
```

Fluentd with this configuration will format records to plain text file as 1-liner JSON, and send it to `http://my.server.example.com/upload` by POST request with `file` request parameter, and attachment name `data.2016-02-24-13-59-59` (using uploading date/time).

### Configuration parameters

* uri (string)
  * Endpoint URI to send POST request (http or https) [required]
* param_name
  * POST request parameter name used for file uploading [default: `file`]
* user_agent
  * User-Agent header for HTTP requests [default: `fluent-plugin-http_file_upload` + httpclient/ruby versions]
* headers
  * Additional HTTP headers for requests, specified as JSON hash object [default: `{}`]
* parameters
  * Additional multipart/form-data request parameters, specified as JSON hash object [default: `{}`]
* filename
  * Filename used in uploading request, which can include time fomatter (see [strftime](http://docs.ruby-lang.org/en/2.3.0/Time.html#method-i-strftime)) [default: `data.%Y-%m-%d-%H-%M-%S`]
* format
  * Specifier how to format records into text (see [Text Formatter Overview](http://docs.fluentd.org/articles/formatter-plugin-overview)) [default: `json`]
* include\_time\_key
  * Boolean specifier to include time into records or not [default: `false`]
  * If this parameter is true, these parameters below will be also available:
  * time_key: field name to store formatted time [default: `time`]
  * time_format: format string for time (using strftime) [default: ISO-8601 format]
  * utc: format time as UTC (exclusive with localtime) [default: false]
  * localtime: format time as local time (exclusive with utc) [default: true]

## TODO

* compression for uploaded file
* gzip HTTP content body compression

Pull requests are welcome!

## Copyright

* Copyright (c) 2016- TAGOMORI Satoshi (tagomoris)
* License
  * Apache License, Version 2.0
