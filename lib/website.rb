# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'cgi'
require 'socket'
require 'timeout'
require 'url.rb'
require "func.rb"
require 'http1.rb'
require 'sites.rb'

# キーに文字列だけを取り、キーの大文字小文字を区別しないHash
class IgnoreCaseHash < Hash
  alias set []=
  alias get []
  
  def [](key)
    k = keys.find {|key2| key2.downcase == key.downcase}
    if k then self.get(k) else default end
  end
  
  def []=(key, value)
    raise TypeError if key.class != String
    k = keys.find {|key2| key2.downcase == key.downcase}
    self.set(k || key, value)
  end
end

class Website
  Class_v = {
    'method_abbr' => {'GET'=>'G', 'HEAD'=>'H', 'CACHE'=>'C',
    'FILE'=>'F', 'LENGTH'=>'L', 'KEYWORD'=>'K', 'ERROR'=>'0'}
  }

  attr_reader :url
  attr_accessor :checkurl
  attr_accessor :lastmodified, :lastdetected, :size
  attr_accessor :code, :methods, :authorized
  attr_accessor :remoteurl, :keyword, :tz
  attr_accessor :di
  attr_writer :title, :author, :expires
  
  def author
    if @author != "" then
      @author
    else
      @di['X-WDB-Author-Name'] || ""
    end
  end
  
  def title
    if @title != "" then
      @title
    else
      @di['X-WDB-Title'] || ""
    end
  end
  
  def method
    @methods[0] || ""
  end
  
  def expires
    if @expires != 0 then
      @expires
    elsif @lastdetected != 0 then
      @lastdetected + 28800
    else
      0
    end
  end
  
  def Website.method_abbr; Class_v['method_abbr']; end
  def Website.method_abbr=(abbr_hash); Class_v['method_abbr'] = abbr_hash; end
  
  ## <http://masshy.fastwave.gr.jp/hina/release/usage.html#protocol>
  def Website.hina(str, antenna_url = "")
    raise TypeError if str.class != String || antenna_url.class != String
    
    if str =~ /<!--(.*?)--><a href=(.*?)>(.*?)<\/a>(.*)/i then
      hina_comment = $1
      url = $2
      title = $3.strip
      author = $4.strip
      
      if hina_comment =~ /(.*?) (.*) \[(.*)\]/ then
	hina_method = $1
	lastmodified = str2unixtime($2, "JST")
	hina_code = $3
      else
	hina_method = hina_comment
      end
      
      if url =~ /^"(.*)"$/ then
	url = $1
      end
      
      if author =~ /(.*)<br>/i then
	author = $1
      end
      
      case hina_method
      when "HINA_REMOTE_OUT", "HINA_NOT_FOUND", "HINA_BUSY",
	"HINA_TIMEOUT", "CERN"
	website = Website::new(url, "", title, author)
	website.methods = ["ERROR"]
      when "HINA_UNKNOWN"
	website = Website::new(url, "", title, author)
	website.methods = ["LENGTH"]
      when "HINA_OK"
	website = Website::new(url, "", title, author)
	website.lastmodified = lastmodified
	website.tz = "JST"
	case hina_code
	when "0"
	  website.lastdetected = $start - 28800 + 3600
	  website.expires = $start + 3600
	  website.methods = ["GET"]
	when "1"
	  website.lastdetected = $start - 28800 + 1800
	  website.expires = $start + 1800
	  website.methods = ["REMOTE"]
	else
	  website.lastdetected = $start - 28800 + 300
	  website.expires = $start + 300
	  website.methods = ["REMOTE"]
	end
	if website.lastmodified > website.lastdetected then
	  website.lastdetected = website.lastmodified
	end
      else
	raise ArgumentError
      end
      if antenna_url != "" then
	website.methods = ["REMOTE"]
	website.remoteurl = antenna_url
      end
    else
      raise ArgumentError
    end
    website
  end

  ## <http://www.urawa-reds.org/natsu/doc/LIRS.html>  
  def Website.lirs(str, antenna_url = "")
    raise TypeError if str.class != String || antenna_url.class != String
    
    array = csv_split(str, 14..-1)
    raise ArgumentError if array[0] != "LIRS"
    
    website = Website::new(array[5], array[9], array[6], array[7])
    website.lastmodified = array[1].to_i
    website.lastdetected = array[2].to_i
    website.tz = lag2tz(array[3].to_i)
    website.size = array[4].to_i
    website.authorized = array[8]
    if not antenna_url.empty? then
      website.methods = ["REMOTE"]
      website.remoteurl = antenna_url
    elsif array[1] == "0" && array[2] == "0" then
      website.methods = ["ERROR"]
    else
      case array[13]
      when "GET", "HEAD", "CACHE", "FILE", "LENGTH", "KEYWORD"
	website.methods = [array[13]]
      else
	website.methods = ["REMOTE"]
	website.remoteurl = array[13]
      end
    end
    website
  end

  ## <http://kohgushi.fastwave.gr.jp/hina-doc/>
  def Website.di(str, antenna_url = "")
    raise TypeError if str.class != String || antenna_url.class != String
    
    di = IgnoreCaseHash::new
    lines = str.split(/\r?\n/)
    lines.each {|line|
      line.chomp!
      if line =~ /(.*?):\s+(.*)/ then
	key = $1
	value = $2
	di[key] = value
      end
    }
    
    raise ArgumentError if di["URL"] == nil
    website = Website::new(di["URL"], di["Virtual"] || "",
			   di["Title"] || "", di["Author-Name"] || "")
    di.each {|key, value|
      case key
      when "URL", "Author-Name", "Title", "Virtual"
      when "Method", "X-TAMA-Method", "Expires", "Expire"
      when "Last-Modified"
	website.lastmodified = str2unixtime(di['Last-Modified'])
      when "Last-Modified-Detected"
	website.lastdetected = str2unixtime(di['Last-Modified-Detected'])
      when "Authorized-url"
	website.authorized = di['Authorized-url']
      when "X-TAMA-Remote-URL"
	website.remoteurl = di['X-TAMA-Remote-URL']
      when "X-TAMA-Keyword"
	website.keyword = di['X-TAMA-Keyword']
      when "Content-Length"
	website.size = di['Content-Length'].to_i
      when "X-TAMA-Timezone"
	website.tz = di['X-TAMA-Timezone']
      else
	website.di[key] = value
      end
    }
    expires = di['Expires'] || di['Expire'] || ""
    website.expires = str2unixtime(expires)
    
    method = di['X-TAMA-Method'] || di['Method'] || ""
    methods = method.split('/')
    if methods[-1].to_i != 0 then
      website.code = methods[-1].to_i
      # method = []の時、method[0..-2]=nil
      website.methods = methods[0..-2] || []
    else
      website.code = 0
      website.methods = methods
    end
    
    if not antenna_url.empty? then
      website.methods = ["REMOTE"] + website.methods
      website.remoteurl = antenna_url
    end
    website
  end
  
  def initialize(url, checkurl = "", title = "", author = "")
    if url.class == Site then
      site = url
      @title = site.title
      @author = site.author
      @url = site.url
      @checkurl = site.checkurl
    else
      raise ArgumentError if url.empty?
      @title = title
      @author = author
      @url = url
      @checkurl = URL::new(checkurl, url).to_s
    end
    
    @lastmodified = 0
    @lastdetected = 0
    @tz = ""
    @size = 0
    # 更新時刻を自力でチェックしたアンテナのURL
    @authorized = ""
    
    # 情報を取得したアンテナのURL
    @remoteurl = ""
    @keyword = ""
    @methods = []
    @code = 0
    @expires = 0 
    
    @di = IgnoreCaseHash::new
  end
  
  def remote?
    if self.method == "REMOTE" then TRUE else FALSE end
  end
  
  def natsu_ext
    checkurl = if @checkurl.file? || @checkurl == @url then "" else @checkurl end
    
    case self.method
    when "REMOTE"
      return [checkurl, "", "", "", @remoteurl]
    when "ERROR"
      return [checkurl, "", "", "", ""]
    else
      return [checkurl, "", "", "", self.method]
    end
  end
  private :natsu_ext
  
  def to_lirs
    raise StandardError if self.method.empty?
    csv_join("LIRS", self.method == "ERROR" ? 0 : @lastmodified,
	     self.method == "ERROR" ? 0 : @lastdetected,
	     tz2lag(self.tz), self.size, @url,
	     @title, @author, @authorized, natsu_ext)
  end
  
  def to_hina
    time = Time::at(@lastmodified + 32400).gmtime # JST固定
    timestr = time.strftime('%Y/%m/%d %H:%M')
    linkstr = "<A HREF=\"#{@url}\">#{@title}</A> #{@author}"
    
    case self.method
    when "GET", "HEAD", "CACHE", "FILE"
      ret = "<!--HINA_OK #{timestr} [0]-->#{linkstr}<br>"
    when "LENGTH", "KEYWORD"
      if @lastmodified == 0 then
	"<!--HINA_UNKNOWN-->#{linkstr}<br>"
      else
	"<!--HINA_OK #{timestr} [1]-->#{linkstr}<br>"
      end
    when "REMOTE"
      if @lastmodified == 0 then
	"<!--HINA_REMOTE_OUT-->#{linkstr}<br>"
      else
	"<!--HINA_OK #{timestr} [1]-->#{linkstr}<br>"
      end
    when "ERROR"
      "<!--HINA_REMOTE_OUT-->#{linkstr}<br>"
    else
      raise StandardError
    end
  end
  
  def to_di
    ret = ""
    ret << "URL: #{@url}\r\n"
    ret << "Title: #{@title}\r\n" unless @title.empty?
    ret << "Author-Name: #{@author}\r\n" unless @author.empty?
    ret << "Virtual: #{@checkurl}\r\n" if @checkurl != @url && @checkurl.file? == false
    if @lastmodified != 0 then
      time = Time::at(@lastmodified).gmtime
      timestr = time.strftime("%a, %d %b %Y %X GMT")
      ret << "Last-Modified: #{timestr}\r\n"
    end
    if @lastdetected != 0 then
      time = Time::at(@lastdetected).gmtime
      timestr = time.strftime("%a, %d %b %Y %X GMT")
      ret << "Last-Modified-Detected: #{timestr}\r\n"
    end
    
    if self.expires != 0 then
      time = Time::at(self.expires).gmtime
      timestr = time.strftime("%a, %d %b %Y %X GMT")
      ret << "Expires: #{timestr}\r\n"
      ret << "Expire: #{timestr}\r\n"
    end
    ret << "Content-Length: #{self.size}\r\n" if self.size != 0
    ret << "Authorized-url: #{@authorized}\r\n" unless @authorized.empty?
    ret << "X-TAMA-Remote-URL: #{@remoteurl}\r\n" unless @remoteurl.empty?
    ret << "X-TAMA-Keyword: #{@keyword}\r\n" unless @keyword.empty?
    ret << "X-TAMA-Timezone: #{self.tz}\r\n" unless self.tz.empty?
    
    if @methods - ["GET", "HEAD", "FILE", "REMOTE"] == [] && @code != 0 then
      ret << "Method: #{@methods.join('/')}/#{@code}\r\n"
    elsif @code != 0 then
      ret << "X-TAMA-Method: #{@methods.join('/')}/#{@code}\r\n"
    else
      ret << "X-TAMA-Method: #{@methods.join('/')}\r\n"
    end
    
    @di.each {|key, value|
      ret << "#{key}: #{value}\r\n"
    }
    ret
  end
  
  def format(formatstr, suffix)
    error = (self.method == "ERROR" || @lastmodified == 0 ? TRUE : FALSE)
    
    time = Time::at(@lastmodified + tz2lag(tz)).gmtime
    formatstr =~ /^([^%]*)(.*)$/
    ret = $1 + $2.gsub(/%([^%]*)%/) {|pattern|
      case $1
      when "year"
	if error == TRUE then "----" else "%04d" % time.year end
      when "month", "day", "hour", "min", "sec"
	if error == TRUE then "--" else "%02d" % time.send($1) end
      when "url"
	if error == FALSE && suffix != nil then
	  suffix =~ /^([^%]*)(.*)$/
	  @url + $1 + $2.gsub(/%[^%]*%/) {|pattern|
	    case pattern
	    when "%month%"
	      "%02d" % time.month
	    when "%day%"
	      "%02d" % time.day
	    when "%hour%"
	      "%02d" % time.hour
	    when "%min%"
	      "%02d" % time.min
	    when "%%"
	      "%"
	    end
	  }
	else
	  @url
	end
      when "title"
	CGI::escapeHTML(@title)
      when "author"
	if @author == "0" then "" else CGI::escapeHTML(@author) end
      when "method"
	if Class_v['method_abbr'][self.method] then
	  Class_v['method_abbr'][self.method]
	elsif Class_v['method_abbr'][@remoteurl] then
	  Class_v['method_abbr'][@remoteurl]
	else
	  "-"
	end
      when "tz"
	self.tz
      when "authorized"
	CGI::escapeHTML(@authorized)
      when "keyword"
	'["' + CGI::escapeHTML(@keyword) + '"]' unless @keyword.empty?
      when ""
	"%"
      else
	pattern
      end
    }
    ret
  end
end
