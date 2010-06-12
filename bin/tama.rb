#%ruby_path%

# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

# カレントディレクトリの変更
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

def usage()
  puts "Usage: tama.rb [--noget] [--local] [--version] [--help] [--check]"
  puts "               [--config-file-name file-name]"
  puts "               [--output-directory-name dir-name]"
  puts "               [--force] [--verbose] [--debug]"
  puts "詳しい使い方は 'tama.rb --help'を実行して下さい。"
end

$USAGE = 'usage'
parseArgs(0, nil, nil, "noget", "local", "version", "debug", "help", "check", "config-file-name:", "output-directory-name:", "force", "verbose")

if $OPT_version == TRUE then
  puts "#{TAMA::Version}"
  exit
end

if $OPT_help == TRUE then
  puts "Usage: tama.rb [--noget] [--local] [--version] [--help] [--check]"
  puts "               [--config-file-name file-name]"
  puts "               [--output-directory-name dir-name]"
  puts "               [--force] [--verbose] [--debug]"
  puts
  puts "  --noget              更新情報を取得せずに出力だけします。"
  puts "  --local              ローカルファイルのみ更新時刻を取得します。"
  puts "  --version            バージョンを表示します。"
  puts "  --help               このヘルプを表示します。"
  puts "  --check              設定ファイルの書式をチェックします。"
  puts "  --force              更新時刻間隔の変更を無効にしてチェックします。"
  puts "  --verbose            詳細なメッセージを出力します。"
  puts "  --debug              デバッグ用のメッセージを出力します。"
  exit
end

if $OPT_output_directory_name then
  $outdir = $OPT_output_directory_name.dup
  $outdir.untaint
end
verbose("Output directory: #{$outdir}\n")

if !File::exists?($outdir) || File::ftype($outdir) != 'directory' then
  puts "#{$outdir} はディレクトリではありません。"
  exit
end

$tama_cfg_path = "./conf/tama.cfg"
if $OPT_config_file_name then
  $tama_cfg_path = $OPT_config_file_name
end
verbose("Config: #{$tama_cfg_path}\n")
load $tama_cfg_path

# セキュリティを強化
$SAFE = 1

if $OPT_check == TRUE then
  puts "チェックを開始します。"
  puts ""
  check_format()
  puts "チェックが終了しました。"
  exit
end

TAMA_REMOTE_FILE = "./tmp/_remote.di"
TAMA_GET_FILE = "./tmp/_sites_get.di"
TAMA_SITES_FILE = "./tmp/_sites.di"

$start = Time::now.to_i

# タイムゾーンの設定
if $tz == nil then
  warning("$tzが設定されていません。")
  $tz = 'JST'
end

# スレッド数の設定
if $max_threads == nil then
  $max_threads = 1
end

verbose("Version: #{TAMA::Version}\n")
verbose("Build: #{TAMA::Build}\n\n")

# リモート情報を取得する。
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
  # ファイル探索
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
  
  # リモート情報の利用
  if !site.option['NO_REMOTE'] && remote && remote.expires > $start &&
    remote.lastmodified != 0 then
    verbose("URL: #{site.checkurl}\n" +
	  "    => Use remote\n")
    return remote
  end
  
  # --localの時はfile://以外チェックしない
  # cacheはnilが入ることもあるので注意。
  return cache if $OPT_local == TRUE
  
  # 一日以上更新されていない場合
  if cache then
    lm_days = (Time::now.to_i - cache.lastmodified) / 86400.0
    ld_hours = (Time::now.to_i - cache.lastdetected) / 3600.0
    if ld_hours < 24 && lm_days > 1 &&
      lm_days / ld_hours > 1 && $OPT_force != TRUE then
      verbose("URL: #{site.checkurl}\n" +
	    "    => Skip [lm_days = #{'%.2f' % lm_days}, ld_hours = #{'%.2f' % ld_hours}]\n")
      return cache
    end
    
    # ftpの場合は常に一日一回。
    if site.checkurl.ftp? == TRUE && ld_hours < 24 &&
      $OPT_force != TRUE then
      verbose("URL: #{site.checkurl}\n" +
	    "    => Skip [ld_hours = #{'%.2f' % ld_hours}]\n")
      return cache
    end
  end
  
  # ftp探索
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
  
  # HEADリクエスト
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
      # Netscape-Enterpriseの時はwebsiteはnilを返す
      return website if website
    end
  end
  
  # GET取得
  headers = {}
  #headers['Referer'] = $referer unless $referer.nil? || $referer.empty?
  http1_get = HTTP1::get(site.checkurl, headers)
  
  # DIによる判定
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
  
  # キーワード判定
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
  
  # GETでLast-Modifiedがある場合
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
  
  # LENGTH判定
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

# $sitesで指定してある*.cfgから*.tamaなどを作成する。
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

# HTMLに出力する。
def antenna_out()
  remotes = Remotes::open("./conf/remote.cfg")
  
  $html.each {|basehtml, outhtml|
    out = File::open(outhtml, "w")
    lines = File::open(basehtml).read
    # $htmlで指定されるファイルには問題無いと仮定
    lines.untaint
    
    out.puts lines.gsub(/<!--tama_output[ \n]((.|\n)*?)-->/) {|match|
      option = attr_split(match)
      if option['suffix'] != nil then
	warning("#{basehtml}: suffixを使用しています。formatを使うようにしてください。\n")
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
  # キャッシュ情報＆リモート情報の読み込み。
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
	
	# sites.size > 0 だけど、実際はsites = []だったときを考慮
	# (スレッド対応のため)
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
    # ログを書き込む
    f.puts ""
  end
  verbose("Traffic: #{HTTP1.traffic} bytes\n")
  verbose("Date: #{Time::now.to_s}\n\n")
end

verbose("Check finished\n\n")

out_tama()

antenna_out()

verbose("Finished\n")
