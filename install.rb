# 「たまてばこ」version 1.1.66
# Copyright(C) 2000-2001 Hideki Ikemoto

require 'parsearg'

def usage()
  puts "Usage: install.rb [-f filename]"
end
$USAGE = 'usage'
parseArgs(0, nil, nil, "f:")

if $OPT_f then
  $setup = File::expand_path($OPT_f)
else
  $setup = "#{ENV['HOME']}/.tama_setup_beta"
end

$VERSION = "1.1.66"
include FileTest

if $0.index('/') != nil then
  Dir::chdir $0[0..$0.rindex('/')]
end

# ファイルのコピー
def copy(from_path, to_path)
  str = ""
  File::open(from_path) do |rf|
    str = rf.read
  end
  
  File::open(to_path, "w") do |wf|
    wf.print str
  end
end

# インストールする
def install()
  if not exist?("#{$install_path}") then
    Dir::mkdir($install_path, 0755)
  end
  
  if not exist?("#{$install_path}/conf") then
    Dir::mkdir("#{$install_path}/conf", 0755)
  end
  
  if not exist?("#{$install_path}/html") then
    Dir::mkdir("#{$install_path}/html", 0755)
  end
  
  if not exist?("#{$install_path}/tmp") then
    Dir::mkdir("#{$install_path}/tmp", 0755)
  end
  
  if not exist?("#{$install_path}/lib") then
    Dir::mkdir("#{$install_path}/lib", 0755)
  end
  
  if not exist?("#{$out_path}") then
    Dir::mkdir($out_path, 0755)
  end
  
  # ファイルのコピー(手抜き^^;)
  Dir::foreach("lib") {|file|
    next if file == "."
    next if file == ".."
    puts("#{file}をコピー中...")
    copy("lib/#{file}", "#{$install_path}/lib/#{file}")
  }
  
  puts("sites.cfgをコピー中...")
  if exist?("#{$install_path}/conf/sites.cfg") then
    puts "sites.cfgが見付かりました。"
    puts "設定の見本はsites.cfg.origとしてコピーされます。"
    copy("conf/sites.cfg", "#{$install_path}/conf/sites.cfg.orig")
  else
    copy("conf/sites.cfg", "#{$install_path}/conf/sites.cfg")
  end
  
  puts("remote.cfgをコピー中...")
  if exist?("#{$install_path}/conf/remote.cfg") then
    puts "remote.cfgが見付かりました。"
    puts "設定の見本はremote.cfg.origとしてコピーされます。"
    copy("conf/remote.cfg", "#{$install_path}/conf/remote.cfg.orig")
  else
    copy("conf/remote.cfg", "#{$install_path}/conf/remote.cfg")
  end
  
  puts("base.htmlをコピー中...")
  if exist?("#{$install_path}/html/base.html") then
    puts "base.htmlが見付かりました。"
    puts "設定の見本はbase.html.origとしてコピーされます。"
    copy("html/base.html", "#{$install_path}/html/base.html.orig")
  else
    copy("html/base.html", "#{$install_path}/html/base.html")
  end
  
  puts("tama.cfgをコピー中...")
  if exist?("#{$install_path}/conf/tama.cfg") then
    puts "tama.cfgが見付かりました。"
    puts "設定の見本はtama.cfg.origとしてコピーされます。"
    copy("conf/tama.cfg", "#{$install_path}/conf/tama.cfg.orig")
  else
    copy("conf/tama.cfg", "#{$install_path}/conf/tama.cfg")
  end
  
  puts("tama.rbをコピー中...")
  system("sed -e 's|^#%ruby_path%|#!#{$ruby_path}|' " +
	 "-e 's|^#%out_path%|$outdir = \"#{$out_path}\"|' " +
	 "-e 's|^#%antenna_url%|$referer = \"#{$antenna_url}\"|' " +
	 "-e 's|^#%gzip_path%|$gzip = \"#{$gzip_path}\"|' " +
	 "< bin/tama.rb > #{$install_path}/tama.rb")
  
  # 実行可能にする
  mode = File::stat("#{$install_path}/tama.rb").mode
  File::chmod(mode | 0700, "#{$install_path}/tama.rb")
  
  File::open($setup,"w") do |f|
    f.puts "TAMA_VERSION=#{$VERSION}"
    f.puts "RUBY_PATH=#{$ruby_path}"
    f.puts "GZIP_PATH=#{$gzip_path}"
    f.puts "INSTALL_PATH=#{$install_path}"
    f.puts "OUT_PATH=#{$out_path}"
    f.puts "ANTENNA_URL=#{$antenna_url}"
  end
  
  puts
  puts "インストールが終了しました。"
  puts "設定情報は#{$setup}に保存されました。"
end

# ここからスタート
$ruby_path = ""
$gzip_path = ""
$install_path = ""
$out_path = ""

puts "「たまてばこ」version #{$VERSION}のインストールを始めます。"
puts "いくつかのファイルを上書きしますので、"
puts "念のためバックアップを取って下さい。"
puts "(Enterキーで先に進みます)"
$stdin.readline

# $setup(デフォルトは~/.tama_setup)を検索
if exist?($setup) then
  puts "#{$setup}が見つかりました。"
  lines = File::readlines($setup)
  lines.each {|line|
    key, value = line.chomp.split(/=/)
    case key
    when "RUBY_PATH"
      $ruby_path = value
    when "GZIP_PATH"
      $gzip_path = value
    when "INSTALL_PATH"
      $install_path = value
    when "OUT_PATH"
      $out_path = value
    when "ANTENNA_URL"
      $antenna_url = value
    when "TAMA_VERSION"
      $tama_version = value
    end
  }
  puts "以前の設定情報が見付かりました。"
  puts 
  puts "バージョン     : #{$tama_version}"
  puts "ruby           : #{$ruby_path}"
  puts "gzip           : #{$gzip_path}"
  puts "設定ファイル   : #{$install_path}"
  puts "出力先         : #{$out_path}"
  puts "URL            : #{$antenna_url}"
  
  puts
  puts "以上の設定でよろしいですか? [Y/n]"
  answer = $stdin.readline.chomp
  if answer != "n" && answer != "N" then
    install()
    exit
  end
else
  puts "#{$setup}が見つかりませんでした。"
end

# rubyの場所を検索
puts "rubyを探しています..."
$ruby_path = `which ruby`

if $ruby_path.empty? then
  puts "rubyが見付かりませんでした。rubyのパスを入力して下さい。"
  print "> "
  $ruby_path = $stdin.readline.chomp
else
  $ruby_path.chomp!
  puts "rubyが '#{$ruby_path}' に見付かりました。これでよろしいですか? [Y/n]"
  answer = $stdin.readline.chomp
  if answer == "n" || answer == "N" then
    puts "rubyのパスを入力して下さい。"
    print "> "
    $ruby_path = $stdin.readline.chomp
  end
end

# rubyのバージョンをチェック
ruby_version_str = `#{$ruby_path} --version`
if ruby_version_str.empty? then
  puts "rubyのバージョンが取得できませんでした。終了します。"
  exit(1)
else
  ruby_version_str =~ /ruby ([0-9\.]+)/
  $ruby_version = $1
end

# gzipの場所を検索
puts 
puts "gzipを探しています..."
$gzip_path = `which gzip`

if $gzip_path.empty? then
  puts "gzipが見付かりませんでした。gzipのパスを入力して下さい。"
  print "> "
  $gzip_path = $stdin.readline.chomp
else
  $gzip_path.chomp!
  puts "gzipが '#{$gzip_path}' に見付かりました。これでよろしいですか? [Y/n]"
  answer = $stdin.readline.chomp
  if answer == "n" || answer == "N" then
    puts "gzipのパスを入力して下さい。"
    print "> "
    $gzip_path = $stdin.readline.chomp
  end
end

# インストールの場所
puts
puts "設定ファイルをインストールするディレクトリを入力して下さい。[#{ENV['HOME']}/antenna]"
print "> "
$install_path = $stdin.readline.chomp
if $install_path.empty? then
  $install_path = "#{ENV['HOME']}/antenna"
end

# HTMLの出力先
puts
puts "出力先ディレクトリを入力して下さい。[#{ENV['HOME']}/public_html/antenna]"
print "> "
$out_path = $stdin.readline.chomp
if $out_path.empty? then
  $out_path = "#{ENV['HOME']}/public_html/antenna"
end

# アンテナのURL(HTTP_REFERERで送られる)
puts
puts "アンテナのURLを入力して下さい。[]"
print "> "
$antenna_url = $stdin.readline.chomp

puts 
puts "ruby           : #{$ruby_path} (#{$ruby_version})"
puts "gzip           : #{$gzip_path}"
puts "設定ファイル   : #{$install_path}"
puts "出力先         : #{$out_path}"
puts "URL            : #{$antenna_url}"

puts
puts "以上の設定でよろしいですか? [Y/n]"
answer = $stdin.readline.chomp
if answer == "n" || answer == "N" then
  puts "終了します。"
  exit(1)
end

# インストール開始
install()
