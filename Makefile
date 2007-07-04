.PHONY: all autoloads lisp doc clean realclean distclean fullclean install
.PHONY: test dist release debclean debprepare debbuild debinstall deb upload
.PRECIOUS: %.elc

include Makefile.defs

EL  = $(filter-out $(PROJECT)-autoloads.el,$(wildcard *.el))
ELC = $(patsubst %.el,%.elc,$(EL))

all: autoloads lisp $(MANUAL).info

lisp: $(ELC)

$(PROJECT)-build.elc: ./scripts/$(PROJECT)-build.el
	@echo $(PROJECT)-build.el is not byte-compiled

autoloads: $(PROJECT)-autoloads.el

$(PROJECT)-autoloads.el: $(EL)
	@$(EMACS) -q $(SITEFLAG) -batch -l ./scripts/$(PROJECT)-build.el \
		-f $(PROJECT)-generate-autoloads . contrib

%.elc: %.el
	@$(EMACS) -q $(SITEFLAG) -batch -l ./scripts/$(PROJECT)-build.el \
		-f batch-byte-compile $< || :

%.info: %.texi
	makeinfo $<

%.html: %.texi
	makeinfo --html --no-split $<

doc: $(MANUAL).info $(MANUAL).html

clean:
	-rm -f *.elc *~

realclean fullclean: clean
	-rm -f $(MANUAL).info $(MANUAL).html $(PROJECT)-autoloads.el

install: autoloads lisp $(MANUAL).info
	install -d $(ELISPDIR)
	install -m 0644 $(PROJECT)-autoloads.el $(EL) $(wildcard *.elc) \
	    $(ELISPDIR)
	[ -d $(INFODIR) ] || install -d $(INFODIR)
	install -m 0644 $(MANUAL).info $(INFODIR)/$(MANUAL)
	$(INSTALLINFO) $(INFODIR)/$(MANUAL)

test: $(ELC)
	$(EMACS) -q $(SITEFLAG) -batch -l ./scripts/$(PROJECT)-build.el \
		-f $(PROJECT)-elint-files $(EL)

distclean:
	-rm -f $(MANUAL).info $(MANUAL).html debian/dirs debian/files
	-rm -fr ../$(PROJECT)-$(VERSION)

dist: autoloads distclean
	tla inventory -sB | tar -cf - --no-recursion -T- | \
	  (mkdir -p ../$(PROJECT)-$(VERSION); cd ../$(PROJECT)-$(VERSION) && \
	  tar xf -)
	cp $(PROJECT)-autoloads.el ../$(PROJECT)-$(VERSION)
	rm -fr ../$(PROJECT)-$(VERSION)/debian ../$(PROJECT)-$(VERSION)/test

release: dist
	(cd .. && tar -czf $(PROJECT)-$(VERSION).tar.gz \
	          $(PROJECT)-$(VERSION) && \
	  zip -r $(PROJECT)-$(VERSION).zip $(PROJECT)-$(VERSION) && \
	  gpg --detach $(PROJECT)-$(VERSION).tar.gz && \
	  gpg --detach $(PROJECT)-$(VERSION).zip)

debclean:
	-rm -f ../../dist/$(DISTRIBUTOR)/$(DEBNAME)_*
	-rm -fr ../$(DEBNAME)_$(VERSION)*

debprepare:
	-rm -rf ../$(DEBNAME)-$(VERSION)
	(cd .. && tar -xzf $(PROJECT)-$(VERSION).tar.gz)
	mv ../$(PROJECT)-$(VERSION) ../$(DEBNAME)-$(VERSION)
	(cd .. && tar -czf $(DEBNAME)_$(VERSION).orig.tar.gz \
	    $(DEBNAME)-$(VERSION))
	(cd debian && tla inventory -sB | tar -cf - --no-recursion -T- | \
	  (mkdir -p ../../$(DEBNAME)-$(VERSION)/debian; \
	    cd ../../$(DEBNAME)-$(VERSION)/debian && \
	    tar xf -))

debbuild:
	(cd ../$(DEBNAME)-$(VERSION) && \
	  dpkg-buildpackage -v$(LASTUPLOAD) $(BUILDOPTS) \
	    -us -uc -rfakeroot && \
	  echo "Running lintian ..." && \
	  lintian -i ../$(DEBNAME)_$(VERSION)*.deb || : && \
	  echo "Done running lintian." && \
	  echo "Running linda ..." && \
	  linda -i ../$(DEBNAME)_$(VERSION)*.deb || : && \
	  echo "Done running linda." && \
	  debsign)

debinstall:
	cp ../$(DEBNAME)_$(VERSION)* ../../dist/$(DISTRIBUTOR)

deb: debclean debprepare debbuild debinstall

upload: release
	(cd .. && \
	  scp $(PROJECT)-$(VERSION).zip* $(PROJECT)-$(VERSION).tar.gz* \
	    mwolson@download.gna.org:/upload/planner-el)
