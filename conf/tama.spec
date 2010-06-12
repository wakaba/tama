%define mainversion 1.1.66
%define modversion 1
%define version %{mainversion}mod%{modversion}
%define realversion %{mainversion}-mod%{modversion}

Name:      tama
Summary:   TAMATEBAKO: A Web Page Update Checker (Antenna)
Version:   %{version}
Release:   1.suika
License:   「たまてばこ」を利用した際のトラブルについて作者は一切の責任を負いません。再配布、改造は自由ですが、著作権表示やこの条件リストがある場合はそれを削除しない事。

Group:     Applications/Internet
URL:       http://suika.fam.cx/gate/git/wi/web/tama.git/
Vendor:    Wakaba <w@suika.fam.cx>

BuildRoot: %{_tmppath}/%{name}-%{realversion}-%(id -u -n)
BuildArch: noarch
Prefix:    %(echo %{_prefix})

Requires:  ruby

Source0:   %{name}-%{realversion}.tar.gz

%description
TAMATEBAKO is a so-called "antenna" system, which checks last-modified
dates of Web sites and generate HTML links.  It is written in Ruby,
has support for output formats of other antenna systems, and has
simple configuration format.

%description -l ja
「たまてばこ」とは各サイトの更新時刻を取得してHTMLに出力する、いわゆる
「アンテナ」と呼ばれるシステムです。Rubyで書かれている、他のアンテナの
出力する形式に対応している、設定がシンプルであるといった特徴を持ってい
ます。

%define tamainstallpath /usr/share/tama/
%define tamaconfinstallpath /etc/tama/
%define tamaoutputpath /var/tama/antenna/
%define tamatmppath /var/tama/cache/
%define __ruby %(which ruby)

%prep
%setup -q -n %{name}-%{realversion} 
chmod -R u+w %{_builddir}/%{name}-%{realversion}

echo "TAMA_VERSION=%{realversion}" > install.conf
echo "PATH_PREFIX=%{buildroot}" >> install.conf
echo "RUBY_PATH=%{__ruby}" >> install.conf
echo "GZIP_PATH=%{__gzip}" >> install.conf
echo "INSTALL_PATH=%{tamainstallpath}" >> install.conf
echo "CONF_INSTALL_PATH=%{tamaconfinstallpath}" >> install.conf
echo "OUT_PATH=%{tamaoutputpath}" >> install.conf
echo "TMP_PATH=%{tamatmppath}" >> install.conf
echo "ANTENNA_URL=file:///tama/" >> install.conf

echo "" > installinput.dat
echo "Y" >> installinput.dat

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}
mkdir -p %{buildroot}%{tamainstallpath}
mkdir -p %{buildroot}%{tamaconfinstallpath}
mkdir -p %{buildroot}%{tamaoutputpath}
mkdir -p %{buildroot}%{tamatmppath}

cat installinput.dat | ruby install.rb -f install.conf

cd %{buildroot}%{tamaconfinstallpath} && mv conf/tama.cfg conf/tama.cfg.orig
cd %{buildroot}%{tamaconfinstallpath} && mv conf/sites.cfg conf/sites.cfg.orig
cd %{buildroot}%{tamaconfinstallpath} && mv conf/remote.cfg conf/remote.cfg.orig
cd %{buildroot}%{tamaconfinstallpath} && mv html/base.html html/base.html.orig

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(-,root,root)
%{tamainstallpath}/tama.rb
%{tamainstallpath}/lib
%{tamaconfinstallpath}/conf/tama.cfg.orig
%{tamaconfinstallpath}/conf/sites.cfg.orig
%{tamaconfinstallpath}/conf/remote.cfg.orig
%{tamaconfinstallpath}/html/base.html.orig
%{tamaoutputpath}
%{tamatmppath}
%doc doc/

%changelog
* Sat Jun 12 2010 Wakaba <w@suika.fam.cx> - 1.1.66mod1-1.suika
- Initial build.
