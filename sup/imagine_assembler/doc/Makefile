
# PDF viewer
pdfview = evince
# any changes to these files will trigger recompile
refreshFiles = *.tex
loopInterval = 2




default: list


list:
	@echo List of all targets
	@LC_ALL=C $(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | sed 's/^/  /'


IMAGine-ISA.pdf: IMAGine-ISA.tex
	pdflatex IMAGine-ISA
	# bibtex IMAGine-ISA
	pdflatex IMAGine-ISA
	pdflatex IMAGine-ISA
	$(pdfview) IMAGine-ISA.pdf &


# Vigilantly compiles and refreshes the pdf whenever any of the refreshFiles changes
refresh-loop:
	@while true ; do \
		for x in $(refreshFiles); do \
			if [ $$x -nt IMAGine-ISA.pdf ]; then \
				echo $$x changes. Recompiling ...; \
				pdflatex IMAGine-ISA; \
			fi; \
		done; \
		sleep $(loopInterval); \
	done


# Cleans the workspace
clean:
	rm -f *.aux *.toc *.lof *.lot *.log *.bbl *.blg *.tmp *.out


clean-all: clean
	rm -f *.pdf *.dvi *.ps
