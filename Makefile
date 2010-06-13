RPM = rpm
RPMBUILD = rpmbuild

RPM_SPEC_DIR = $(shell $(RPM) --eval "%{_specdir}")
RPM_SOURCE_DIR = $(shell $(RPM) --eval "%{_sourcedir}")

all: tarball

tarball:
	sh bin/create-tarball.sh

$(RPM_SOURCE_DIR)/tama-tarball: tarball
	mv tama-*.tar.gz $(RPM_SOURCE_DIR)/

$(RPM_SPEC_DIR)/tama.spec: conf/tama.spec
	cp $< $@

rpm: $(RPM_SPEC_DIR)/tama.spec $(RPM_SOURCE_DIR)/tama-tarball
	$(RPMBUILD) -ba $<

debug: bin/prepare-debug-env.rb bin/tama.rb
	ruby $<

## Author: Wakaba <w@suika.fam.cx>
## License: Public Domain.
