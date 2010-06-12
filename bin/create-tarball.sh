#!/bin/sh

basename=tama-`ruby -e 'load "lib/tama_m.rb"; puts "#{TAMA::Version}"'`
tarname=$basename.tar
gzname=$tarname.gz
if [ -f $gzname ]; then
  echo "$gzname: File exists"
  exit 1
fi

echo $tarname...

mkdir $basename || exit 1

cp -R --preserve=timestamps bin lib doc conf html tools config *.rb *.ja Makefile $basename
tar -cf $tarname --exclude=*~ --atime-preserve --preserve-permission --owner apache --group apache $basename
gzip $tarname

rm -fr $basename

## Author: Wakaba <w@suika.fam.cx>
## License: Public Domain.
