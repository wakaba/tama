#%ruby_path%

# �֤��ޤƤФ���version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

# �����ȥǥ��쥯�ȥ���ѹ�
$:.push("./lib")
if $0.index('/') != nil then
  Dir::chdir $0[0..$0.rindex('/')]
end

require 'parsearg'
require 'socket'
require 'nkf'
require 'thread'

require "func.rb"
require "url.rb"
require "di.rb"
require "lirs.rb"
require "hina.rb"
require "website.rb"
require "remote.rb"
require "antenna_out.rb"
require "tama_m.rb"
require "sites.rb"

#%gzip_path%
#%out_path%
#%antenna_url%
#%mail_address%

load "./conf/tama.cfg"

def usage()
  puts "Usage: tama.rb [--noget] [--local] [--version] [--help] [--check]"
  puts "               [--force] [--verbose] [--debug]"
  puts "�ܤ����Ȥ����� 'tama.rb --help'��¹Ԥ��Ʋ�������"
end

$USAGE = 'usage'
parseArgs(0, nil, nil, "noget", "local", "version", "debug", "help", "check", "force", "verbose")

# �������ƥ��򶯲�
$SAFE = 1

if $OPT_version == TRUE then
  puts "#{TAMA::Version}"
  exit
end

if $OPT_help == TRUE then
  puts "Usage: tama.rb [--noget] [--local] [--version] [--help] [--check]"
  puts "               [--force] [--verbose] [--debug]"
  puts
  puts "  --noget              �����������������˽��Ϥ������ޤ���"
  puts "  --local              ������ե�����Τ߹��������������ޤ���"
  puts "  --version            �С�������ɽ�����ޤ���"
  puts "  --help               ���Υإ�פ�ɽ�����ޤ���"
  puts "  --check              ����ե�����ν񼰤�����å����ޤ���"
  puts "  --force              ��������ֳ֤��ѹ���̵���ˤ��ƥ����å����ޤ���"
  puts "  --verbose            �ܺ٤ʥ�å���������Ϥ��ޤ���"
  puts "  --debug              �ǥХå��ѤΥ�å���������Ϥ��ޤ���"
  exit
end

if $OPT_check == TRUE then
  puts "�����å��򳫻Ϥ��ޤ���"
  puts ""
  check_format()
  puts "�����å�����λ���ޤ�����"
  exit
end

TAMA_REMOTE_FILE = "./tmp/_remote.di"
TAMA_GET_FILE = "./tmp/_sites_get.di"
TAMA_SITES_FILE = "./tmp/_sites.di"

$start = Time::now.to_i

# �����ॾ���������
if $tz == nil then
  warning("$tz�����ꤵ��Ƥ��ޤ���")
  $tz = 'JST'
end

# ����åɿ�������
if $max_threads == nil then
  $max_threads = 1
end

verbose("Version: #{TAMA::Version}\n")
verbose("Build: #{TAMA::Build}\n\n")

# ��⡼�Ⱦ����������롣
def get_remote()
  verbose("Get remote files\n\n")
  
  sites_remote = Antenna::new  
  remotes = Remotes::open("./conf/remote.cfg")
  remotes.each { |remote|
    checkurl = URL::new(remote.src, remote.url).to_s
    verbose("GET: #{checkurl}\n")
    case remote.dataformat
    when "LIRS"
      antenna = LIRS::open(remote.src, remote.url)
    when "DI"
      antenna = DI::open(remote.src, remote.url)
    when "HINA"
      antenna = HINA::open(remote.src, remote.url)
    end
    verbose("GET: #{checkurl}\n" +
	  "    => Succeed. size = #{antenna.size}\n")
    sites_remote.merge!(antenna)
  }
  sites_remote.save(TAMA_REMOTE_FILE, "DI")
end

def get_site(site, cache, remote)
  # �ե�����õ��
  if site.checkurl.file? == TRUE then
    website = site.check_file
    if website.method == "FILE" then
      verbose("FILE: #{site.checkurl}\n" +
	    "    => Succeed\n")
    else
      verbose("FILE: #{site.checkurl}\n" +
	    "    => Error\n")
    end
    return website
  end
  
  # ��⡼�Ⱦ��������
  if !site.option['NO_REMOTE'] && remote && remote.expires > $start &&
    remote.lastmodified != 0 then
    verbose("URL: #{site.checkurl}\n" +
	  "    => Use remote\n")
    return remote
  end
  
  # --local�λ���file://�ʳ������å����ʤ�
  # cache��nil�����뤳�Ȥ⤢��Τ���ա�
  return cache if $OPT_local == TRUE
  
  # �����ʾ幹������Ƥ��ʤ����
  if cache then
    lm_days = (Time::now.to_i - cache.lastmodified) / 86400.0
    ld_hours = (Time::now.to_i - cache.lastdetected) / 3600.0
    if ld_hours < 24 && lm_days > 1 &&
      lm_days / ld_hours > 1 && $OPT_force != TRUE then
      verbose("URL: #{site.checkurl}\n" +
	    "    => Skip [lm_days = #{'%.2f' % lm_days}, ld_hours = #{'%.2f' % ld_hours}]\n")
      return cache
    end
    
    # ftp�ξ��Ͼ�˰������
    if site.checkurl.ftp? == TRUE && ld_hours < 24 &&
      $OPT_force != TRUE then
      verbose("URL: #{site.checkurl}\n" +
	    "    => Skip [ld_hours = #{'%.2f' % ld_hours}]\n")
      return cache
    end
  end
  
  # ftpõ��
  if site.checkurl.ftp? == TRUE then
    website = site.check_ftp(cache)
    if website.method == "HEAD" then
      verbose("FTP: #{site.checkurl}\n" +
	    "    => Succeed\n")
    else
      verbose("FTP: #{site.checkurl}\n" +
	    "    => Error [#{website.code}]\n")
    end
    return website
  end
  
  # HEAD�ꥯ������
  if !site.option['DI'] && !site.option['GET'] && !site.option['REGEXP'] then
    website = site.check_head(cache)
    if website then
      if website.method == "HEAD" then
	verbose("HEAD: #{site.checkurl}\n" +
	      "    => Succeed [#{website.code}]\n")
      else
	verbose("HEAD: #{site.checkurl}\n" +
	      "    => Error [#{website.code}]\n")
      end
      # Netscape-Enterprise�λ���website��nil���֤�
      return website if website
    end
  end
  
  # GET����
  headers = {}
  headers['Referer'] = $referer unless $referer.nil? || $referer.empty?
  http1_get = HTTP1::get(site.checkurl, headers)
  
  # DI�ˤ��Ƚ��
  if site.option['DI'] then
    website = site.check_di(http1_get, cache)
    if website.method == "GET" then
      verbose("hina-di check: #{site.checkurl}\n" +
	    "    => Succeed\n")
    else
      verbose("hina-di check: #{site.checkurl}\n" +
	    "    => Error [#{website.code}]\n")
    end
    return website
  end
  
  # �������Ƚ��
  if site.option['REGEXP'] then
    website = site.check_keyword(http1_get, cache, site.option['REGEXP'])
    if website then
      if website.method == "ERROR" then
	verbose("Keyword check: #{site.checkurl}\n" +
	      "    => Error #{website.code}]\n")
      elsif cache == nil then
	verbose("Keyword check: #{site.checkurl}\n" +
	      "    => No cache\n")
      elsif cache.keyword == website.keyword then
	verbose("Keyword check: #{site.checkurl}\n" +
	      "    => Not change\n")
      else
	verbose("Keyword check: #{site.checkurl}\n" +
	      "    => ['#{cache.keyword}' -> '#{website.keyword}']\n")
      end
      return website
    end
  end
  
  # GET��Last-Modified��������
  website = site.check_get(http1_get, cache)
  if website then
    if website.method == "GET" then
      verbose("GET: #{site.checkurl}\n" +
	    "    => Succeed [#{website.code}]\n")
    else
      verbose("GET: #{site.checkurl}\n" +
	    "    => Error [#{website.code}]\n")
    end
    return website
  end
  
  # LENGTHȽ��
  website = site.check_length(http1_get, cache)
  if cache == nil then
    verbose("Length check: #{site.checkurl}\n" +
	  "    => No cache\n")
  elsif cache.size != http1_get.body.size then
    verbose("Length check: #{site.checkurl}\n" +
	  "    => [#{cache.size} -> #{http1_get.body.size}]\n")
  else
    verbose("Length check: #{site.checkurl}\n" + 
	  "    => Not change\n")
  end
  website
end

# $sites�ǻ��ꤷ�Ƥ���*.cfg����*.tama�ʤɤ�������롣
def out_tama()
  websites = DI::open(TAMA_SITES_FILE)
  
  $site.each {|cfgpath, savepath|
    antenna = Antenna::new
    sites = Sites::open(cfgpath)
    sites.each {|site|
      website = websites.find {|site_get| site_get.url == site.url}
      if website then
	website.tz = site.option['TZ'] || $tz
	website.title = site.title unless site.title.empty?
	website.author = site.author unless site.author.empty?
      else
	website = Website::new(site)
      end
      antenna.push(website)
    }
    antenna.save("#{$outdir}/#{savepath}.lirs", "LIRS")
    antenna.save("#{$outdir}/#{savepath}.di", "DI")
    antenna.save("#{$outdir}/#{savepath}.txt", "HINA")
    antenna.save("#{$outdir}/#{savepath}.lirs.gz", "LIRS", TRUE)
    antenna.save("#{$outdir}/#{savepath}.di.gz", "DI", TRUE)
    antenna.save("#{$outdir}/#{savepath}.txt.gz", "HINA", TRUE)
    antenna.save("./tmp/#{savepath}.lirs", "LIRS")
    antenna.save("./tmp/#{savepath}.di", "DI")
    antenna.save("./tmp/#{savepath}.txt", "HINA")
    antenna.save("./tmp/#{savepath}.lirs.gz", "LIRS", TRUE)
    antenna.save("./tmp/#{savepath}.di.gz", "DI", TRUE)
    antenna.save("./tmp/#{savepath}.txt.gz", "HINA", TRUE)
  }
end

# HTML�˽��Ϥ��롣
def antenna_out()
  remotes = Remotes::open("./conf/remote.cfg")
  
  $html.each {|basehtml, outhtml|
    out = File::open(outhtml, "w")
    lines = File::open(basehtml).read
    # $html�ǻ��ꤵ���ե�����ˤ�����̵���Ȳ���
    lines.untaint
    
    out.puts lines.gsub(/<!--tama_output[ \n]((.|\n)*?)-->/) {|match|
      option = attr_split(match)
      if option['suffix'] != nil then
	warning("#{basehtml}: suffix����Ѥ��Ƥ��ޤ���format��Ȥ��褦�ˤ��Ƥ���������\n")
      end
      
      if option['method'] == nil then
	antenna_out__default(option, remotes)
      elsif respond_to?("antenna_out_#{option['method']}", TRUE) then
	send("antenna_out_#{option['method']}", option, remotes)
      else
	line
      end
    }
  }
end

# main

if $OPT_noget != TRUE && $OPT_local != TRUE then
  get_remote()
  verbose("\n")
  verbose("Traffic: #{HTTP1.traffic} bytes\n")
  verbose("Date: #{Time::now.to_s}\n\n")
end

remotes = Remotes::open("./conf/remote.cfg")
remotes.each {|remote|
  Website::method_abbr[remote.url] = "<a href=\"#{remote.url}\">#{remote.abbr}</a>"
}

if $OPT_noget != TRUE then
  sites = Sites::new
  $site.each {|cfgpath, savepath|
    sites.merge!(Sites::open(cfgpath))
  }
  sites_get = Antenna::new
  # ����å���������⡼�Ⱦ�����ɤ߹��ߡ�
  begin
    sites_cache = DI::open(TAMA_GET_FILE)
  rescue
    sites_cache = DI::new
  end
  
  begin
    sites_remote = DI::open(TAMA_REMOTE_FILE)
  rescue
    sites_remote = DI::new
  end
  
  threads = []
  lock = Mutex::new
  for i in 0...$max_threads
    t = Thread::new {
      while sites.size > 0 do
	site = nil
	lock.synchronize {
	  site = sites.shift
	}
	
	# sites.size > 0 �����ɡ��ºݤ�sites = []���ä��Ȥ����θ
	# (����å��б��Τ���)
	if site then
	  cache = sites_cache.find{|site_cache| site_cache.url == site.url}
	  remote = sites_remote.find{|site_remote| site_remote.url == site.url}
	  
	  website = get_site(site, cache, remote)
	  
	  lock.synchronize {
	    if website then
	      sites_get.push(website)
	    else
	      sites_get.push(Website::new(site))
	    end
	    verbose("\n")
	  }
	end
      end
    }
    threads.push(t)
  end
  
  threads.each {|t|
    if t.alive?
      t.join
    end
  }
  
  sites_get.save(TAMA_GET_FILE, "DI") {|site| site.method != "REMOTE" }
  sites_get.save(TAMA_SITES_FILE, "DI")
  
  File::open("./tmp/log", "w") do |f|
    # ����񤭹���
    f.puts ""
  end
  verbose("Traffic: #{HTTP1.traffic} bytes\n")
  verbose("Date: #{Time::now.to_s}\n\n")
end

verbose("Check finished\n\n")

out_tama()

antenna_out()

verbose("Finished\n")
