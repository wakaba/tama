# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'cgi'
require "func.rb"

Remote = Struct::new("Remote", :title, :url, :src, :dataformat, :abbr)

class Remote
  def format(formatstr)
    formatstr =~ /^([^%]*)(.*)$/
    ret = $1 + $2.gsub(/%[^%]*%/) {|pattern|
      case pattern
      when "%title%"
	CGI::escapeHTML(self.title)
      when "%url%"
	self.url
      when "%abbr%"
	self.abbr
      when "%format%"
	case self.dataformat
	when "LIRS"
	  '<a href="http://amano.haun.org/LIRS.html">LIRS</a>'
	when "DI"
	  '<a href="http://docinfo.jin.gr.jp/">DI</a>'
	when "HINA"
	  '<a href="http://masshy.fastwave.gr.jp/hina/release/">hina.txt</a>'
	else
	  self.dataformat
	end
      else
      end
    }
  end
end

class Remotes < Array
  def Remotes.open(path)
    ret = Remotes::new
    ret.read(path) unless path.empty?
    ret
  end
  
  def read_ver1(lines)
    conf_a = []

    lines.each {|line|
      next if line =~ /^#/
      
      if line.empty? then
	option = {}
	url = title = checkurl = format = symbol = ""
	conf_a.each {|conf|
	  if conf =~ /^(.*?):\s*(.*)/ then
	    key = $1.downcase
	    value = $2
	    case key
	    when "url"
	      url = value
	    when "format"
	      format = value
	    when "title"
	      title = value
	    when "data-url"
	      checkurl = value
	    when "symbol"
	      symbol = value
	    end
	  end
	}
	
	unless url.empty? then
	  remote = Remote::new(title, url, checkurl, format, symbol)
	  push(remote)
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
      
      csv = csv_split(line.chomp, 5..-1)
      remote = Remote::new(csv[0], csv[1], csv[2], csv[3], csv[4])
      push(remote)
    }
  end
end
