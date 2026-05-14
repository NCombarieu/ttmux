NAME     := ttmux
VERSION  := 1.3.0
RPMBUILD ?= $(HOME)/rpmbuild

.PHONY: all tarball rpm install clean distclean

all: rpm

tarball:
	@mkdir -p $(RPMBUILD)/SOURCES
	@tmp=$$(mktemp -d) && \
	  mkdir $$tmp/$(NAME)-$(VERSION) && \
	  cp $(NAME) $(NAME).1 $$tmp/$(NAME)-$(VERSION)/ && \
	  tar czf $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION).tar.gz -C $$tmp $(NAME)-$(VERSION) && \
	  rm -rf $$tmp
	@echo "-> $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION).tar.gz"

rpm: tarball
	@mkdir -p $(RPMBUILD)/SPECS
	cp $(NAME).spec $(RPMBUILD)/SPECS/
	rpmbuild -bb $(RPMBUILD)/SPECS/$(NAME).spec

install:
	install -D -m 0755 $(NAME)   $(DESTDIR)/usr/bin/$(NAME)
	install -D -m 0644 $(NAME).1 $(DESTDIR)/usr/share/man/man1/$(NAME).1

clean:
	rm -f $(RPMBUILD)/SOURCES/$(NAME)-$(VERSION).tar.gz

distclean: clean
	rm -rf $(RPMBUILD)/BUILD/$(NAME)-$(VERSION)*
	rm -f  $(RPMBUILD)/RPMS/noarch/$(NAME)-$(VERSION)-*.noarch.rpm
	rm -f  $(RPMBUILD)/SRPMS/$(NAME)-$(VERSION)-*.src.rpm
