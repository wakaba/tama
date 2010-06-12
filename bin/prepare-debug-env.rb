#!/usr/bin/ruby

$ruby_path = '/usr/bin/ruby'
$out_path = './debugout/'
$antenna_url = 'file:///testantenna/'
$gzip_path = '/bin/gzip'
$mail_address = ''
$install_path = '.'

  system("sed -e 's|^#%ruby_path%|#!#{$ruby_path}|' " +
	 "-e 's|^#%out_path%|$outdir = \"#{$out_path}\"|' " +
	 "-e 's|^#%antenna_url%|$referer = \"#{$antenna_url}\"|' " +
	 "-e 's|^#%gzip_path%|$gzip = \"#{$gzip_path}\"|' " +
	 "-e 's|^#%mail_address%|$mail_address = \"#{$mail_address}\"|' " +
	 "< bin/tama.rb > #{$install_path}/tama.rb")