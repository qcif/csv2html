# Makefile

help:
	@echo "Targets:"
	@echo "  all   - run csv2html to generate example HTML files"
	@echo "  clean - delete all generated HTML files"

EXTRA=\
  output-include-hidden.html \
  output-exclude-other.html \
  output-no-template.html

all: output.html ${EXTRA}

output.html: template.csv data.csv
	../bin/csv2html.dart -o $@ -t template.csv data.csv

output-include-hidden.html: template.csv data.csv
	../bin/csv2html.dart -o $@ -t template.csv --include-hidden data.csv

output-exclude-other.html: template.csv data.csv
	../bin/csv2html.dart -o $@ -t template.csv --exclude-other data.csv

output-no-template.html: data.csv
	../bin/csv2html.dart -o $@ data.csv

clean:
	rm -f ${EXTRA}
