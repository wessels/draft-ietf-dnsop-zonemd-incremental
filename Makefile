#
# built using mmark 2.
# on fedora: sudo dnf install golang-github-mmarkdown-mmark

VERSION = 00
DOCNAME = draft-wessels-dnsop-zonemd-incremental
XML=Versions/$(DOCNAME)-$(VERSION).xml
TXT=Versions/$(DOCNAME)-$(VERSION).txt
HTML=Versions/$(DOCNAME)-$(VERSION).html

all: ${TXT} ${HTML}

${TXT}: ${XML}
	@mkdir -p $$(dirname $@)
	@xml2rfc --text -o $@ $<

${HTML}: ${XML}
	@mkdir -p $$(dirname $@)
	@xml2rfc --html -o $@ $<

${XML}: $(DOCNAME).md
	@mkdir -p $$(dirname $@)
	@sed 's/@DOCNAME@/$(DOCNAME)-$(VERSION)/g' $< | mmark > $@

clean:
	rm -vf ${XML}
	rm -vf ${TXT}
	rm -vf ${HTML}
