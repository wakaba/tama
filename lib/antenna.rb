# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'tempfile'
require "url.rb"
require "func.rb"
require "website.rb"

class Antenna < Array
  def push(site)
    super.push(site) if find{|site2| site2.url == site.url} == nil
  end
  
  def merge(antenna)
    newantenna = Antenna::new
    
    urls = collect{|site| site.url} | antenna.collect{|site| site.url}
    urls.each{|url|
      site1 = find{|site| site.url == url}
      site2 = antenna.find{|site| site.url == url}
      
      if site1 == nil then
	latest = site2
      elsif site2 == nil then
	latest = site1
      elsif site1.lastdetected >= site2.lastdetected then
	latest = site1
      else
	latest = site2
      end
      newantenna.push(latest)
    }
    newantenna
  end
  
  def merge!(antenna)
    newantenna = merge(antenna)
    clear
    newantenna.each {|site|
      push(site)
    }
  end
  
  def read(antenna_src, antenna_url = "")
    header = {}
    #if $referer != "" then
    #  header['Referer'] = $referer
    #end
    
    url = URL::new(antenna_src, antenna_url)
    str = ""
    case url.scheme
    when 'http'
      http1 = HTTP1::get(url.to_s, header)
      unless http1.code == 0 || http1.code.between?(400, 599) then
	str = http1.body
      else
	return
      end
    when 'file'
      # 要するにファイルのコピー。
      begin
	File::open(url.path) do |rf|
	  str = rf.read
	end
      rescue
	return
      end
    end
    if str.gziped? == TRUE then
      temp = Tempfile::new('tama_tmp')
      temp.print str
      temp.close
      
      str = IO::popen("#{$gzip} -dc < #{temp.path}").read
    end
    lines = str.split(/\r?\n/)
    
    parse(lines, antenna_url)
  end
  
  # parseメソッドはサブクラスで定義する
  def parse(lines, antenna_url)
    puts "can't use Antenna#parse method, please override it."
    exit
  end
  private :parse
  
  def save(path, format, use_gzip = FALSE, &block)
    str = ""
    
    if format == "DI" then
      str << "HINA/2.1\r\n"
      str << "User-Agent: #{TAMA::Agent}\r\n"
      str << "Date: #{Time::now.gmtime.strftime('%a, %d %b %Y %X GMT')}\r\n"
      str << "Content-Type: text/plain; charset=UTF-8\r\n"
      str << "\r\n"
    end
    
    each {|site|
      next if iterator? && yield(site) == false # block_given?は1.6から
      
      begin
	case format
	when "LIRS"
	  str << site.to_lirs << "\n"
	when "DI"
	  str << site.to_di
	  str << "\r\n"
	when "HINA"
	  str << site.to_hina << "\n"
	else
	  raise ArgumentError
	end
      rescue ArgumentError
	raise ArgumentError
      rescue StandardError
	# 無視する
      end
    }
    if use_gzip == TRUE then
      temp = Tempfile::new('tama_save')
      temp.print str
      temp.close
      
      str = IO::popen("#{$gzip} < #{temp.path}").read
    end
    File::open(path, 'w') {|wf|
      wf.print str
    }
  end
end
