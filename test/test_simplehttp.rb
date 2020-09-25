assert '#address' do
  http = SimpleHttp.new('http', '127.0.0.1', 80)
  assert_equal '127.0.0.1', http.address
end

assert '#port' do
  http = SimpleHttp.new('http', '127.0.0.1')
  assert_equal 80, http.port

  http = SimpleHttp.new('https', '127.0.0.1')
  assert_equal 443, http.port

  http = SimpleHttp.new('http', '127.0.0.1', 10080)
  assert_equal 10080, http.port
end


host = '127.0.0.1'
port = 8000
app = Proc.new do |env|
  code = 200
  headers = { 'Server' => 'mruby-simplehttpserver' }
  path = env['PATH_INFO']
  method = env['REQUEST_METHOD']
  body = nil

  case path
  when '/index.html'
    headers['Content-Type'] = 'text/html; charset=utf-8'
    body = 'Hello World'
  when '/notfound'
    # Custom error response message
    body = "Not Found on this server: #{path}"
    code = 404
  end

  if method == 'POST' or method == 'PUT'
    headers['Content-Type'] = 'text/html; charset=utf-8'
    headers['Content-Length'] = env['Content-length']
  end

  [code, headers, [body]]
end

server = SimpleHttpServer.new(server_ip: host, port: port, app: app)
pid = fork { server.run }

# WORKAROUND: if without sleep, it often fails to test.
sleep 1

assert 'SimpleHttp#get' do
  http = SimpleHttp.new('http', host, port)

  res = http.get('/index.html', {'User-Agent' => 'test-agent'})
  assert_equal 200, res.code
  assert_equal '200 OK', res.status
  assert_include res.header.split("\r\n"), 'Content-Type:text/html; charset=utf-8'
  assert_equal 'Hello World', res.body

  res = http.get('/notfound', {'User-Agent' => 'test-agent'})
  assert_equal 404, res.code
  assert_equal '404 Not Found', res.status
  assert_equal 'Not Found on this server: /notfound', res.body
end

assert 'SSL set hostname' do
  # HACK because polarssl hostname is usually write-only
  class PolarSSL::SSL
    attr_reader :hostname
    alias set_hostname2 set_hostname
    def set_hostname(a)
      set_hostname2(a)
      @hostname = a
    end
  end
  http = SimpleHttp.new('https', 'www.google.com', 443)
  assert_equal 'www.google.com', http.ssl.hostname
end

assert 'SimpleHttp#post' do
  skip 'mruby-simplehttpserver doesn\'t yet support for getting message body.'

  http = SimpleHttp.new('http', host, port)

  res = http.post('/upload', {'Body' => 'Hello World', 'Content-Length' => '11'})
  assert_equal 200, res.code
  assert_equal '200 OK', res.status
  assert_include res.header.split("\r\n"), 'Content-Length:11'
end

assert 'SimpleHttp#put' do
  skip 'mruby-simplehttpserver doesn\'t yet support for getting message body.'

  http = SimpleHttp.new('http', host, port)

  res = http.put('/upload', {'Body' => 'Hello World', 'Content-Length' => '11'})
  assert_equal 200, res.code
  assert_equal '200 OK', res.status
  assert_include res.header.split("\r\n"), 'Content-Length:11'
end

Process.kill :TERM, pid
