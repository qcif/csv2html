# Makefile

help:
	@echo "Targets:"
	@echo "  all"
	@echo "  clean"

all: output.html no-template.html

output.html: template.csv data.csv
	../bin/csv2html.dart -o $@ -t template.csv data.csv

no-template.html: data.csv
	../bin/csv2html.dart -o $@ data.csv

clean:
	rm -f output.html no-template.html
