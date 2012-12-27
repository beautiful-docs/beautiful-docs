PATH := ./node_modules/.bin:${PATH}

init:
	npm install

clean:
	rm -rf lib/

build: clean
	cp -r src lib
	find lib -name *.coffee | xargs ./node_modules/.bin/coffee -c
	find lib -name *.coffee | xargs rm

dist: clean init build

publish: dist
	npm publish
