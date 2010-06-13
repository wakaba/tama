#!/usr/bin/ruby

$ruby_path = '/usr/bin/ruby'
$out_path = './debugout/'
$conf_install_path = './'
$tmp_path = './tmp/'
$antenna_url = 'file:///testantenna/'
$gzip_path = '/bin/gzip'
$install_path = './'

  system("sed -e 's|^#%ruby_path%|#!#{$ruby_path}|' " +
	 "-e 's|^#%out_path%|$outdir = \"#{$out_path}\"|' " +
	 "-e 's|^#%conf_path%|$confdir = \"#{$conf_install_path}\"|' " +
	 "-e 's|^#%tmp_path%|$tmpdir = \"#{$tmp_path}\"|' " +
	 "-e 's|^#%antenna_url%|$referer = \"#{$antenna_url}\"|' " +
	 "-e 's|^#%gzip_path%|$gzip = \"#{$gzip_path}\"|' " +
	 "< bin/tama.rb > #{$install_path}/tama.rb")

## Author: Wakaba <w@suika.fam.cx>.
##
## License: Same as Tamatebako Version 1.1.66.
