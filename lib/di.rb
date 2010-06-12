# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'timeout'
require "antenna.rb"
require "tama_m.rb"

class DI < Antenna
  def DI::open(antenna_src, antenna_url = "")
    ret = DI::new
    ret.read(antenna_src, antenna_url) unless antenna_src.empty?
    ret
  end
  
  def parse(lines, antenna_url)
    array = []
    lines.push("")
    
    begin
      until lines.shift.empty?
	# ヘッダを読み飛ばす
      end
    rescue
      return
    end
    
    lines.each {|line|
      if line.empty? then
	begin
	  push(Website::di(array.join("\n"), antenna_url))
	rescue
	  debug("hina-di data broken.\n")
	end
	array.clear
      else
	array.push(line)
      end
    }
  end
  private :parse
end
