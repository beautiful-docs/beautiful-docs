
all: public modules

modules:
	npm install express
	npm install coffee-script
	npm install eco
	npm install less
	npm install node-markdown
    
public:
	mkdir -p public/css
	mkdir -p public/js
    
clean:
	rm -r public
