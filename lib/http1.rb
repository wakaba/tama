# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'url.rb'
require 'socket'
require 'timeout'
require 'func'
require 'tama_m'

class HTTP1Error < StandardError; end
class HTTP1MethodError < HTTP1Error; end

class HTTP1
  Class_v = {
    'timeout' => 30,
    'traffic' => 0
  }
  
  attr_reader :body, :code, :url
  attr_accessor :method
  def initialize(url)
    @url = url
    
    @body = ""
    @code = 0
    @headers = {}
    @method = ""
  end
  
  def HTTP1.timeout; Class_v['timeout']; end
  def HTTP1.timeout=(num); Class_v['timeout'] = num; end
  def HTTP1.traffic; Class_v['traffic']; end
  
  def HTTP1.head(url, headers = {})
    count = 1
    
    ret = HTTP1::new(url)
    ret.connect('HEAD', headers)
    while (ret.code == 301 || ret.code == 302) && count < 5
      url = ret['Location']
      url.untaint if url.http? == TRUE
      ret = HTTP1::new(url)
      ret.connect('HEAD', headers)
      count += 1
    end
    ret
  end
  
  def HTTP1.get(url, headers = {})
    count = 1
    
    ret = HTTP1::new(url)
    ret.connect('GET', headers)
    while (ret.code == 301 || ret.code == 302) && count < 5
      url = ret['Location']
      url.untaint if url.http? == TRUE
      ret = HTTP1::new(url)
      ret.connect('GET', headers)
      count += 1
    end
    ret
  end
  
  def [](key)
    @headers[key.downcase]
  end
  
  def connect(method, headers = {})
    s = nil
    begin
      timeout(HTTP1.timeout) {
	url = URL::new(@url)
	s = TCPSocket.open(url.domain, url.port)
	case method
	when 'HEAD', 'GET'
	  if url.query.empty? then
	    s.write("#{method} #{url.path} HTTP/1.0\r\n")
	  else
	    s.write("#{method} #{url.path}?#{url.query} HTTP/1.0\r\n")
	  end
	  @method = method
	else
	  raise HTTP1MethodError
	end
	headers.each {|key, value|
	  s.write("#{key}: #{value}\r\n")
	}
	s.write("Connection: close\r\n")
	s.write("Host: #{url.domain}\r\n")
	s.write("Accept: */*\r\n")
	s.write("User-Agent: #{TAMA::Agent}\r\n") unless TAMA::Agent.empty?
	s.write("\r\n")
	
	s_a = s.readlines
	s_a.shift =~ %r|^HTTP/(.*?) (.*?) (.*)$|
	@code = $2.to_i
	
	@headers.clear
	while (str = s_a.shift) != nil
	  str.chop!
	  break if str.empty?
	  str =~ /^(.*?): ?(.*)$/
	  @headers[$1.downcase] = $2
	end
	
	@body = ""
	while (str = s_a.shift) != nil
	  @body << str
	  Class_v['traffic'] += str.size
	end
      }
    rescue HTTP1MethodError
      raise HTTP1MethodError
    rescue
      @method = 'ERROR'
      @code = 0
      @body = ""
      @headers.clear
    ensure
      if s.class == TCPSocket then
	s.close
      end
    end
  end
end
