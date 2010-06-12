# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'nkf'

IN_NAME = :IN_NAME     # name="value"のnameの状態
IN_VALUE = :IN_VALUE   # name="value"のvalueの状態
IN_NORMAL = :IN_NORMAL # それ以外(separatorとか)
IN_ESCAPE = :IN_ESCAPE # \でエスケープした状態

def attr_split(src)
  ret = {}
  status = IN_NORMAL
  name = ""
  value = ""
  tmp = ""
  escaped = FALSE
  
  str_a = src.split(//)
  str_a.each {|char|
    case status
    when IN_NAME
      if char == "=" then
	name = tmp
	status = IN_VALUE
	tmp = ""
      elsif char =~ /\s/ then
	ret[tmp] = "yes"
	status = IN_NORMAL
	tmp = ""
      else
	tmp += char
      end
    when IN_VALUE
      if escaped == TRUE then
	escaped = FALSE
	tmp += char
      elsif char == '\\' then
	escaped = TRUE
      elsif char == '"' && tmp != "" then
	ret[name] = tmp[1..-1]
	status = IN_NORMAL
	tmp = ""
      else
	tmp += char
      end
    when IN_NORMAL
      if char !~ /\s/ then
	status = IN_NAME
	tmp += char
      end
    end
  }
  ret
end

# 終了している(バックスラッシュで終わっていない)時にtrue
def unescape(str)
  data = ""
  status = IN_NORMAL
  
  str.split(//).each {|char|
    case status
    when IN_NORMAL
      if char == "\\" then
	status = IN_ESCAPE
      else
	data += char
      end
    when IN_ESCAPE
      data += char
      status = IN_NORMAL
    end
  }
  if status == IN_ESCAPE then
    return IN_ESCAPE, data
  else
    return IN_NORMAL, data
  end
end

def csv_split(src, range = nil)
  case range
  when Range
    min = range.first
    max = range.last
  when Fixnum
    min = range
    max = range
  else
    min = 0
    max = -1
  end
  
  ret = []
  data = ""
  status = IN_NORMAL
  src.split(/,/, -1).each {|item|
    if item.index(/\\/) == nil then
      ret.push(data + item)
      data = ""
      status = IN_NORMAL
    else
      status, str = unescape(item)
      if status == IN_NORMAL then # エスケープ処理で終わっていない
	ret.push(data + str)
	data = ""
      else
	data += str + ','
      end
    end
  }
  if status == IN_ESCAPE then
    if data != "" then
      data[-1] = '\\'
    else
      data = '\\'
    end
  end
  ret.push(data) if data != ""
  
  ret.push("") while ret.size < min
  if max >= 0 then
    ret[0...max]
  else
    ret
  end
end

def csv_join(*array)
  ret = ""
  array.each {|item|
    if item.kind_of?(Array) then
      item.each {|i|
	str = i.to_s.gsub(/\\/,"\\\\").gsub(/,/,"\\,")
	ret += str + ","
      }
    else
      str = item.to_s.gsub(/\\/,"\\\\").gsub(/,/,"\\,")
      ret += str + ","
    end
  }
  ret.chop
end

def tz2lag(str)
  timezone = {"PST"=>-8, "MST"=>-7, "PDT"=>-7, "MDT"=>-6, "CST"=>-6,
  "CDT"=>-5, "EST"=>-5, "EDT"=>-4, "GMT"=>0, "UT"=>0, "BST"=>1, "CET"=>1,
  "MET"=>1, "EET"=>2, "JST"=>9}
  
  if timezone[str] != nil then
    timezone[str] * 60 * 60
  elsif str =~ /^\+([0-9][0-9])00$/ then
    $1.to_i * 60 * 60
  elsif str =~ /^-([0-9][0-9])00$/ then
    - $1.to_i * 60 * 60
  else
    0
  end
end  

def lag2tz(num)
  timezone = {9=>"JST", 2=>"EET", 1=>"CET", 0=>"GMT",
  -4=>"EDT", -5=>"EST", -6=>"CST", -7=>"PDT", -8=>"PST"}
  
  hour = num / 3600
  if timezone[hour] != nil then
    timezone[hour]
  elsif hour >= 0 then
    sprintf("+%02d00",hour)
  else
    sprintf("-%02d00",- hour)
  end
end

def str2unixtime(str, tz = nil)
  if str =~ /..., (\d?\d) (...) (....) (..):(..):(..) (.*)/ then
    # 標準的なフォーマット(RFC1123)
    lag = tz2lag($7)
    begin
      time = Time::gm($3, $2, $1, $4, $5, $6)
      return time.to_i - lag
    rescue
      return 0
    end
  elsif str =~ /.*, (..)\-(...)\-(..) (..):(..):(..) (.*)/ then
    # RFC850をベースにしたもの
    year = if $3.to_i < 70 then $3.to_i + 2000 else $3.to_i + 1900 end
    month = $2
    day = $1
    hour = $4
    min = $5
    sec = $6
    lag = tz2lag($7)
    begin
      time = Time::gm(year, month, day, hour, min, sec)
      return time.to_i - lag
    rescue
      return 0
    end
  elsif str =~ /... (...) (..) (..):(..):(..) (....)/ then
    # ANSI C のasctime()フォーマット
    year = $6
    month = $1
    day = $2
    hour = $3
    min = $4
    sec = $5
    lag = if tz then tz2lag(tz) else 0 end
    begin
      time = Time::gm(year, month, day, hour, min, sec)
      return time.to_i - lag
    rescue
      return 0
    end
  elsif str =~ %r|(.*)/(..)/(..) (..):(..)| then
    # 朝日奈アンテナ形式
    year = $1.to_i
    month = $2.to_i
    day = $3.to_i
    hour = $4.to_i
    min = $5.to_i
    if year <= 99 then
      # 年が2桁の場合
      year += 1900
    end
    lag = if tz then tz2lag(tz) else 0 end
    begin
      time = Time::gm(year, month, day, hour, min, 0)
      return time.to_i - lag
    rescue
      return 0
    end
  end
  0
end

# --debugが付いているときだけ表示するエラー
def debug(str)
  print str if $OPT_debug == TRUE
end

# --verboseもしくは--debugが付いているときに表示するエラー
def verbose(str)
  print str if $OPT_debug == TRUE || $OPT_verbose == TRUE
end

# 常に表示するエラー
def warning(str)
  print "warning: #{str}"
end

def check_format
  print "現在このオプションはサポートされていません。"
end

class String
  def file?; if self =~ %r|^file://| then TRUE else FALSE end; end
  def http?; if self =~ %r|^http://| then TRUE else FALSE end; end
  def ftp?; if self =~ %r|^ftp://| then TRUE else FALSE end; end
  def gziped?; if self =~ /^\037\213/ then TRUE else FALSE end; end
end
