#!/usr/bin/ruby

# 「たまてばこ」フォーマット変換ツール version 0.0.1
# Copyright(C) 2001 Hideki Ikemoto

if $0.index('/') != nil then
  $:.push($0[0..$0.rindex('/')] + "/../lib/")
else
  $:.push("../lib/")
end
  
require 'parsearg'

require 'func.rb'
require 'sites.rb'

def usage()
  puts "Usage: convert.rb file"
end

$USAGE = 'usage'
parseArgs(1, nil, nil, "t:")

sites = Sites::new(ARGV[0])

puts "Version: 1.2"
puts "Charset: euc-jp"
puts

sites.each {|site|
  opt = []
  puts "URL: #{site.url}"
  puts "Check-URL: #{site.checkurl}" unless site.checkurl.empty? ||
    site.url == site.checkurl
  puts "Title: #{site.title}" unless site.title.empty?
  puts "Author: #{site.author}" unless site.author.empty?
  site.option.each {|key, value|
    if value == "yes" then
      opt.push(key)
    else
      puts "#{key.capitalize}: #{value}"
    end
    
    if opt.size != 0 then
      puts "Option: #{opt.join(',')}"
    end
  }
  puts
}
