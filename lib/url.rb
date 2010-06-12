# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

class URL
  attr_reader :scheme, :domain, :port, :path, :query, :fragment
  
  def initialize(url, base = "")
    @domain = ""
    @port = 0
    @query = ""
    @fragment = ""
    @path = "/"
    
    if base.empty? then
      parse(url)
    else
      parse_with_base(url, base)
    end
  end
  
  # == で比較できるようにする。
  def URL.normalize(str)
    url = URL::new(str)
    case url.scheme
    when "http"
      "http://#{url.domain.downcase}:#{url.port}" +
      url.path.gsub(/%(..)/i) {|match|
	$1.hex.chr
      } + "?#{url.query}##{url.fragment}"
    when "ftp"
      "ftp://#{url.domain.downcase}:#{url.port}" +
      url.path.gsub(/%(..)/i) {|match|
	$1.hex.chr
      }
    when "file"
      "file://" + url.path
    end
  end
  
  def to_s
    case @scheme
    when "http"
      "http://#{@domain}" +
      if @port == 80 then "" else ":#{@port}" end +
      @path +
      if @query.empty? then "" else "?#{@query}" end +
      if @fragment.empty? then "" else "##{@fragment}" end
    when "ftp"
      "ftp://#{@domain}" +
      if @port == 21 then "" else ":#{@port}" end + @path
    when "file"
      "file://" + @path
    end
  end
  
  def parse(str)
    str =~ %r|^(.+?)://(.*)$|
    @scheme = $1
    case @scheme
    when "http"
      $2 =~ %r|^([^/:]+)(:(\d+))?((/[^#\?]*)\??([^#]*)?#?(.*)?)?$|
      @domain = $1
      @port = if $3 == nil then 80 else $3.to_i end
      @path = if $5 == nil then "/" else $5 end
      @query = if $6 == nil then "" else $6 end
      @fragment = if $7 == nil then "" else $7 end
    when "ftp"
      $2 =~ %r|^([^/:]+)(:(\d+))?(/[^#\?]*)?$|
      @domain = $1
      @port = if $3 == nil then 21 else $3.to_i end
      @path = if $4 == nil then "/" else $4 end
    when "file"
      @path = $2 unless $2 && $2.empty?
    else
      @scheme = "file"
      @path = str unless str && str.empty?
    end
  end
  private :parse

  def parse_with_base(url, base)
    baseURL = URL::new(base)
    if url =~ %r!^(http|file|ftp)://! then
      parse(url)
    elsif url[0] == ?/ then
      # 絶対パス
      case baseURL.scheme
      when "http", "ftp"
	parse("#{baseURL.scheme}://#{baseURL.domain}:#{baseURL.port}#{url}")
      when "file"
	parse("#{baseURL.scheme}://#{url}")
      end
    elsif url.empty? then
      parse(base)
    else
      # 相対パス
      basepath_a = baseURL.path.split(/\//, -1)
      basepath_a.shift
      basepath_a.pop
      path_a = url.split(/\//, -1)
      path_a.push("") if url[-1] == ?/ || url == "." || url == ".."
      path_a.each {|path|
	next if path == "."
	if path == ".." then
	  basepath_a.pop
	  next
	end
	basepath_a.push(path)
      }
      path = basepath_a.join('/')
      case baseURL.scheme
      when "http", "ftp"
	parse("#{baseURL.scheme}://#{baseURL.domain}:#{baseURL.port}/#{path}")
      when "file"
	parse("#{baseURL.scheme}:///#{path}")
      end
    end
  end
  private :parse_with_base
end
