TARGETS=network.pdf latency.pdf bandwidth.pdf hamming.pdf graph.pdf hammingfull.pdf strstr.pdf hammingdram.pdf hammingsamsung.pdf hammingisp.pdf

%.ps: %.plot
	gnuplot $<
%.pdf: %.ps
	ps2pdf $<
	pdfcrop $@

all: $(TARGETS)
	mkdir -p obj
	mv *.ps obj
	mv *.pdf obj
