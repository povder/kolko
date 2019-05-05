.DEFAULT_GOAL := build

build: kolko.s
	mkdir -p bin
	gcc -m32 kolko.s -o bin/kolko -nostdlib
	chmod +x bin/kolko

clean:
	rm -f bin/kolko

run: build
	bin/kolko
