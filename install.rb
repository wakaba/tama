# �֤��ޤƤФ���version 1.1.66
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

# �ե�����Υ��ԡ�
def copy(from_path, to_path)
  str = ""
  File::open(from_path) do |rf|
    str = rf.read
  end
  
  File::open(to_path, "w") do |wf|
    wf.print str
  end
end

# ���󥹥ȡ��뤹��
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
  
  # �ե�����Υ��ԡ�(��ȴ��^^;)
  Dir::foreach("lib") {|file|
    next if file == "."
    next if file == ".."
    puts("#{file}�򥳥ԡ���...")
    copy("lib/#{file}", "#{$install_path}/lib/#{file}")
  }
  
  puts("sites.cfg�򥳥ԡ���...")
  if exist?("#{$install_path}/conf/sites.cfg") then
    puts "sites.cfg�����դ���ޤ�����"
    puts "����θ��ܤ�sites.cfg.orig�Ȥ��ƥ��ԡ�����ޤ���"
    copy("conf/sites.cfg", "#{$install_path}/conf/sites.cfg.orig")
  else
    copy("conf/sites.cfg", "#{$install_path}/conf/sites.cfg")
  end
  
  puts("remote.cfg�򥳥ԡ���...")
  if exist?("#{$install_path}/conf/remote.cfg") then
    puts "remote.cfg�����դ���ޤ�����"
    puts "����θ��ܤ�remote.cfg.orig�Ȥ��ƥ��ԡ�����ޤ���"
    copy("conf/remote.cfg", "#{$install_path}/conf/remote.cfg.orig")
  else
    copy("conf/remote.cfg", "#{$install_path}/conf/remote.cfg")
  end
  
  puts("base.html�򥳥ԡ���...")
  if exist?("#{$install_path}/html/base.html") then
    puts "base.html�����դ���ޤ�����"
    puts "����θ��ܤ�base.html.orig�Ȥ��ƥ��ԡ�����ޤ���"
    copy("html/base.html", "#{$install_path}/html/base.html.orig")
  else
    copy("html/base.html", "#{$install_path}/html/base.html")
  end
  
  puts("tama.cfg�򥳥ԡ���...")
  if exist?("#{$install_path}/conf/tama.cfg") then
    puts "tama.cfg�����դ���ޤ�����"
    puts "����θ��ܤ�tama.cfg.orig�Ȥ��ƥ��ԡ�����ޤ���"
    copy("conf/tama.cfg", "#{$install_path}/conf/tama.cfg.orig")
  else
    copy("conf/tama.cfg", "#{$install_path}/conf/tama.cfg")
  end
  
  puts("tama.rb�򥳥ԡ���...")
  system("sed -e 's|^#%ruby_path%|#!#{$ruby_path}|' " +
	 "-e 's|^#%out_path%|$outdir = \"#{$out_path}\"|' " +
	 "-e 's|^#%antenna_url%|$referer = \"#{$antenna_url}\"|' " +
	 "-e 's|^#%gzip_path%|$gzip = \"#{$gzip_path}\"|' " +
	 "< bin/tama.rb > #{$install_path}/tama.rb")
  
  # �¹Բ�ǽ�ˤ���
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
  puts "���󥹥ȡ��뤬��λ���ޤ�����"
  puts "��������#{$setup}����¸����ޤ�����"
end

# �������饹������
$ruby_path = ""
$gzip_path = ""
$install_path = ""
$out_path = ""

puts "�֤��ޤƤФ���version #{$VERSION}�Υ��󥹥ȡ����Ϥ�ޤ���"
puts "�����Ĥ��Υե�������񤭤��ޤ��Τǡ�"
puts "ǰ�Τ���Хå����åפ��äƲ�������"
puts "(Enter��������˿ʤߤޤ�)"
$stdin.readline

# $setup(�ǥե���Ȥ�~/.tama_setup)�򸡺�
if exist?($setup) then
  puts "#{$setup}�����Ĥ���ޤ�����"
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
  puts "������������󤬸��դ���ޤ�����"
  puts 
  puts "�С������     : #{$tama_version}"
  puts "ruby           : #{$ruby_path}"
  puts "gzip           : #{$gzip_path}"
  puts "����ե�����   : #{$install_path}"
  puts "������         : #{$out_path}"
  puts "URL            : #{$antenna_url}"
  
  puts
  puts "�ʾ������Ǥ�����Ǥ���? [Y/n]"
  answer = $stdin.readline.chomp
  if answer != "n" && answer != "N" then
    install()
    exit
  end
else
  puts "#{$setup}�����Ĥ���ޤ���Ǥ�����"
end

# ruby�ξ��򸡺�
puts "ruby��õ���Ƥ��ޤ�..."
$ruby_path = `which ruby`

if $ruby_path.empty? then
  puts "ruby�����դ���ޤ���Ǥ�����ruby�Υѥ������Ϥ��Ʋ�������"
  print "> "
  $ruby_path = $stdin.readline.chomp
else
  $ruby_path.chomp!
  puts "ruby�� '#{$ruby_path}' �˸��դ���ޤ���������Ǥ�����Ǥ���? [Y/n]"
  answer = $stdin.readline.chomp
  if answer == "n" || answer == "N" then
    puts "ruby�Υѥ������Ϥ��Ʋ�������"
    print "> "
    $ruby_path = $stdin.readline.chomp
  end
end

# ruby�ΥС�����������å�
ruby_version_str = `#{$ruby_path} --version`
if ruby_version_str.empty? then
  puts "ruby�ΥС�����󤬼����Ǥ��ޤ���Ǥ�������λ���ޤ���"
  exit(1)
else
  ruby_version_str =~ /ruby ([0-9\.]+)/
  $ruby_version = $1
end

# gzip�ξ��򸡺�
puts 
puts "gzip��õ���Ƥ��ޤ�..."
$gzip_path = `which gzip`

if $gzip_path.empty? then
  puts "gzip�����դ���ޤ���Ǥ�����gzip�Υѥ������Ϥ��Ʋ�������"
  print "> "
  $gzip_path = $stdin.readline.chomp
else
  $gzip_path.chomp!
  puts "gzip�� '#{$gzip_path}' �˸��դ���ޤ���������Ǥ�����Ǥ���? [Y/n]"
  answer = $stdin.readline.chomp
  if answer == "n" || answer == "N" then
    puts "gzip�Υѥ������Ϥ��Ʋ�������"
    print "> "
    $gzip_path = $stdin.readline.chomp
  end
end

# ���󥹥ȡ���ξ��
puts
puts "����ե�����򥤥󥹥ȡ��뤹��ǥ��쥯�ȥ�����Ϥ��Ʋ�������[#{ENV['HOME']}/antenna]"
print "> "
$install_path = $stdin.readline.chomp
if $install_path.empty? then
  $install_path = "#{ENV['HOME']}/antenna"
end

# HTML�ν�����
puts
puts "������ǥ��쥯�ȥ�����Ϥ��Ʋ�������[#{ENV['HOME']}/public_html/antenna]"
print "> "
$out_path = $stdin.readline.chomp
if $out_path.empty? then
  $out_path = "#{ENV['HOME']}/public_html/antenna"
end

# ����ƥʤ�URL(HTTP_REFERER��������)
puts
puts "����ƥʤ�URL�����Ϥ��Ʋ�������[]"
print "> "
$antenna_url = $stdin.readline.chomp

puts 
puts "ruby           : #{$ruby_path} (#{$ruby_version})"
puts "gzip           : #{$gzip_path}"
puts "����ե�����   : #{$install_path}"
puts "������         : #{$out_path}"
puts "URL            : #{$antenna_url}"

puts
puts "�ʾ������Ǥ�����Ǥ���? [Y/n]"
answer = $stdin.readline.chomp
if answer == "n" || answer == "N" then
  puts "��λ���ޤ���"
  exit(1)
end

# ���󥹥ȡ��볫��
install()
