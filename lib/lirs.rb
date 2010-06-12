# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'timeout'
require "http1.rb"
require "antenna.rb"
require "tama_m.rb"

class LIRS < Antenna
  def LIRS::open(antenna_src, antenna_url = "")
    ret = LIRS::new
    ret.read(antenna_src, antenna_url) unless antenna_src.empty?
    ret
  end
  
  def parse(lines, antenna_url)
    lines.each {|line|
      line.chomp!
      next if line == ""
      next if line =~ /^#/
      begin
	push(Website::lirs(line, antenna_url))
      rescue
	debug("lirs data broken.\n")
      end
    }
  end
  private :parse
end
