# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

def antenna_out_REMOTE(option, remotes)
  ret = ""
  remotes.each {|remote|
    ret << remote.format(option['format'] || $tama_remote_output) << "\n"
  }
  ret
end

def antenna_out_LASTMODIFIED(option, remotes)
  file_time = File::mtime($tama_log_path)
  file_time_s = file_time.to_s
  file_time.utc
  file_time_v = file_time.strftime("%Y-%m-%dT%H:%M:%SZ")
  "Last-Modified: <time datetime=\"#{file_time_v}\">#{file_time_s}</time>"
end

def antenna_out_VERSION(option, remotes)
  "「<a href=\"#{TAMA::Official}\">たまてばこ</a>」version #{TAMA::Version}"
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
