# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'timeout'
require 'tama_m.rb'
require "antenna.rb"

class HINA < Antenna
  def HINA::open(antenna_src, antenna_url = "")
    ret = HINA::new
    ret.read(antenna_src, antenna_url) unless antenna_src.empty?
    ret
  end
  
  def parse(lines, antenna_url)
    lines.each {|line|
      line.chomp!
      next if line == ""
      next if line =~ /^#/
      begin
	push(Website::hina(line, antenna_url))
      rescue
	debug("hina.txt data broken.\n")
      end
    }
  end
  private :parse
end
