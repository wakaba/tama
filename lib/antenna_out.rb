# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'cgi'

def antenna_out_REMOTE(option, remotes)
  ret = ""
  remotes.each {|remote|
    ret << remote.format(option['format'] || $tama_remote_output) << "\n"
  }
  ret
end

def antenna_out_LASTMODIFIED(option, remotes)
  file_time = File::mtime("#{$tmpdir}/log")
  file_time_s = file_time.to_s
  file_time.utc
  file_time_v = file_time.strftime("%Y-%m-%dT%H:%M:%SZ")
  if option['type'] == 'html-datetime' then
    file_time_v
  else
    "Last-Modified: <time datetime=\"#{file_time_v}\">#{file_time_s}</time>"
  end
end

def antenna_out_ANTENNA_URL(option, remotes)
  url = $referer
  if option['type'] == 'atom' then url += "sites.atom" end
  if option['escape'] == 'html' then
    CGI::escapeHTML(url)
  else
    url
  end
end

def antenna_out_VERSION(option, remotes)
  if option['type'] == 'text' then
    s = "「たまてばこ」version #{TAMA::Version}"
  else
    s = "「<a href=\"#{TAMA::Official}\">たまてばこ</a>」version #{TAMA::Version}"
  end

  if option['escape'] == 'html' then
    CGI::escapeHTML(s)
  else
    s
  end
end

def antenna_out__default(option, remotes)
  ret = ""
  option['src'] =~ /(.*)\.(.*)/
  name = $1
  suffix = $2

  case suffix
  when 'lirs'
    sites = LIRS::open("#{$tmpdir}/#{name}.#{suffix}")
  when 'di'
    sites = DI::open("#{$tmpdir}/#{name}.#{suffix}")
  when 'tama'
    sites = DI::open("#{$tmpdir}/#{name}.di")
  end

  if option['sort'] == "yes" then
    sites = sites.sort {|a, b|
      (b.method == "ERROR" ? 0 : b.lastmodified) <=>
      (a.method == "ERROR" ? 0 : a.lastmodified)
    }
  end
  
  sites.each_with_index {|site, index|
    ret << site.format(option['format'] || $tama_output,
		       option['suffix']) << "\n"
    break if option['max'] != nil && index + 1 >= option['max'].to_i	
  }
  ret
end
