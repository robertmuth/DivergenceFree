SDK=/usr/lib/dart
DDC=$(SDK)/bin/dartdevc
PORT=8000
PUB=$(SDK)/bin/pub
DART=$(SDK)/bin/dart

clean:
	-rm -fr build/
	-mkdir -p build/web/packages/browser
	-cp -r packages/browser/ build/web/packages/
	-cp web/*html build/web
	-cp web/*css build/web
	-cp web/*js build/web



#--enable-concrete-type-inference
#--enable-checked-mode 
#--minify

get:
	${PUB} get


release:
	${PUB} build --mode release

debug:
	${PUB} build --mode debug

webserver_ddc:
	@echo
	@echo point your browser at http://localhost:8080/divergencefree.html
	@echo
	$(PUB) serve web/ --web-compiler=dartdevc
