# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'net/ftp'

require "func.rb"
require "url.rb"
require "tama_m.rb"
require "website.rb"

class Site
  attr_reader :title, :author, :url, :checkurl, :option
  
  def initialize(title, author, url, checkurl = "", option = {})
    raise ArgumentError if url.empty?
    
    @title = title
    @author = author
    @url = url
    @checkurl = URL::new(checkurl, url).to_s
    @option = option
  end
  
  def check_length(http1, cache = nil)
    raise StandardError if http1 == nil
    ret = Website::new(self)
    
    if cache == nil then
      ret.methods = ["LENGTH"]
      ret.code = http1.code
      ret.size = http1.body.size
    elsif cache.size != http1.body.size then
      ret.methods = ["LENGTH"]
      ret.code = http1.code
      ret.size = http1.body.size
      ret.lastmodified = Time::now.to_i
      ret.lastdetected = Time::now.to_i
    elsif cache.lastmodified == 0 then
      # 一度も更新をチェックしていない時
      ret.methods = ["LENGTH"]
      ret.code = http1.code
      ret.size = http1.body.size
      ret.lastdetected = Time::now.to_i
    else
      # 更新されていないとき
      if cache.method == "CACHE" then
	ret.methods = cache.methods
      else
	ret.methods = ['CACHE'] + cache.methods
      end
      ret.code = cache.code
      ret.size = http1.body.size
      ret.lastmodified = cache.lastmodified
      ret.lastdetected = Time::now.to_i
    end
    ret.di['Authorized'] = TAMA::Agent
    ret.di['Server'] = http1['Server'] if http1['Server']
    ret.authorized = $referer unless $referer == nil || $referer.empty?
    ret
  end
  
  def check_get(http1, cache = nil)
    website = Website::new(self)
    if http1['Last-Modified'] then
      # Last-Modifiedがある時
      website.methods = ["GET"]
      website.code = http1.code
      if http1['Content-Length'] then
	website.size = http1['Content-Length']
      else
	website.size = http1.body.size
      end
      website.lastmodified = str2unixtime(http1['Last-Modified'])
      website.lastdetected = Time::now.to_i
    elsif http1.code == 0 || http1.code.between?(400, 599) then
      # エラーになるとき
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = http1.code
      website.keyword = cache.keyword if cache
    else
      # エラーにならないけどLast-Modifiedが無いとき
      return nil
    end
    website.di['Authorized'] = TAMA::Agent
    website.di['Server'] = http1['Server'] if http1['Server']
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end

  def check_ftp(cache = nil)
    website = Website::new(self)
    checkurl = URL::new(@checkurl)
    address = 'anon@'
    
    begin
      timeout(30) {
	ftp = Net::FTP::open(checkurl.domain, 'anonymous', address)
	website.methods = ["HEAD"]
	website.code = 200
	website.lastmodified = ftp.mtime(checkurl.path).to_i
	website.lastdetected = Time::now.to_i
	website.size = ftp.size(checkurl.path)
      }
    rescue
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = 404
      website.keyword = cache.keyword if cache
    end
    website.di['Authorized'] = TAMA::Agent
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end
  
  def check_file(cache = nil)
    website = Website::new(self)
    checkurl = URL::new(@checkurl)
    if File::exist?(checkurl.path) then
      website.methods = ["FILE"]
      website.code = 200
      website.lastmodified = File::mtime(checkurl.path).to_i
      website.lastdetected = Time::now.to_i
#      website.size = File::size(checkurl.path)
    else
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
#      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = 404
      website.keyword = cache.keyword if cache
    end
    website.di['Authorized'] = TAMA::Agent
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end
  
  def check_head(cache = nil)
    headers = {}
    #headers['Referer'] = $referer unless $referer.nil? || $referer.empty?

    website = Website::new(self)
    http1 = HTTP1::head(@checkurl, headers)
    if http1['Last-Modified'] then
      # Last-Modifiedがあった場合
      website.lastmodified = str2unixtime(http1['Last-Modified'])
      website.lastdetected = Time::now.to_i
      if http1['Content-Length'] then
	website.size = http1['Content-Length']
      else
	website.size = http1.body.size
      end
      website.authorized = $referer
      website.methods = ["HEAD"]
      website.code = http1.code
    elsif http1['Server'] =~ /Netscape-Enterprise/ &&
      http1.code.between?(400, 599) then
      # エラーだけどNetscape-Enterpriseの時は無視
      return nil
    elsif http1.code == 0 || http1.code.between?(400, 599) then
      # エラーの時
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = http1.code
      website.keyword = cache.keyword if cache
    else
      # エラーじゃないけど更新時刻が取得できなかったとき
      return nil
    end
    website.di['Authorized'] = TAMA::Agent
    website.di['Server'] = http1['Server'] if http1['Server']
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end

  def check_di(http1, cache = nil)
    raise StandardError if http1 == nil
    website = Website::new(self)
    if http1.code == 0 || http1.code.between?(400, 599) then
      # エラーになるとき
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = http1.code
      website.keyword = cache.keyword if cache
    else
      di = Website::di(http1.body)
      website.methods = ["GET"]
      website.code = http1.code
      website.lastmodified = di.lastmodified
      website.lastdetected = Time::now.to_i
    end
    website.di['Authorized'] = TAMA::Agent
    website.di['Server'] = http1['Server'] if http1['Server']
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end
  
  def check_keyword(http1, cache, keyword)
    raise StandardError if http1 == nil || keyword == nil
    website = Website::new(self)
    regexp = Regexp.new(keyword)
    body = NKF::nkf('-e', http1.body.tr_s("\r", "\n"))
    if http1.code == 0 || http1.code.between?(400, 599) then
      # エラーになるとき
      website.lastmodified = cache.lastmodified if cache
      website.lastdetected = Time::now.to_i
      website.size = cache.size if cache
      website.authorized = cache.authorized if cache
      website.methods = ["ERROR"]
      website.code = http1.code
      website.keyword = cache.keyword if cache
    else
      catch(:exit) {
	body.split(/\n/).each {|line|
	  matchdata = regexp.match(line)
	  if matchdata then
	    keyword = matchdata.to_a[1..-1].join(', ')
	    if cache == nil then
	      # キャッシュが存在しない場合
	      website.methods = ["KEYWORD"]
	      website.code = http1.code
	    elsif cache.keyword != keyword then
	      website.methods = ["KEYWORD"]
	      website.code = http1.code
	      website.lastmodified = Time::now.to_i
	      website.lastdetected = Time::now.to_i
	    else
	      if cache.method == "CACHE" then
		website.methods = cache.methods
	      else
		website.methods = ['CACHE'] + cache.methods
	      end
	      website.code = cache.code
	      website.lastmodified = cache.lastmodified
	      website.lastdetected = Time::now.to_i
	    end
	    website.keyword = keyword
	    website.size = http1.body.size
	    throw :exit
	  end
	}
	return nil
      }
    end
    website.di['Authorized'] = TAMA::Agent
    website.di['Server'] = http1['Server'] if http1['Server']
    website.authorized = $referer unless $referer == nil || $referer.empty?
    website
  end
end

class Sites < Array
  def Sites::open(path = "")
    ret = Sites::new
    ret.read(path) unless path.empty?
    ret
  end
  
  def merge!(other_sites)
    other_sites.each {|other_site|
      unless find {|site| site.url == other_site.url } then
	push(other_site)
      end
    }
  end
  
  def read_ver1(lines)
    conf_a = []

    lines.each {|line|
      next if line =~ /^#/
      
      if line.empty? then
	option = {}
	url = title = author = checkurl = ""
	conf_a.each {|conf|
	  if conf =~ /^(.*?):\s*(.*)/ then
	    key = $1.downcase
	    value = $2
	    case key
	    when "url"
	      url = value
	    when "author"
	      author = value
	    when "title"
	      title = value
	    when "check-url"
	      checkurl = value
	    when "option"
	      value.split(/,/).each {|op|
		if op =~ /(.*?)=(.*)/ then
		  option[$1] = $2
		else
		  option[op] = "yes"
		end
	      }
	    when "regexp", "tz"
	      option[key.upcase] = value
	    end
	  end
	}
	
	unless url.empty? then
	  site = Site::new(title, author, url, checkurl, option)
	  push(site)
	end
	conf_a.clear
      else
	conf_a.push(line)
      end
    }
  end
  private :read_ver1
  
  def read(path)
    lines = File::readlines(path)
    lines = lines.collect{|line|
      line.chomp!
      line.untaint if path.tainted? == FALSE
      line
    }
    
    if lines[0] =~ /^Version:/i then
      lines.push("")
      read_ver1(lines)
      return
    end
    
    lines.each {|line|
      next if line == ""
      next if line =~ /^#/
      
      csv = csv_split(line, 5..-1)
      option = {}
      csv[4].split('|').each {|op|
	if op =~ /(.*?)=(.*)/ then
	  name = $1
	  value = $2
	else
	  name = op
	  value = "yes"
	end
	option[name] = value
      }
      site = Site::new(csv[0], csv[1], csv[2], csv[3], option)
      push(site)
    }
  end
end
