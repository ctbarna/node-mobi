all:
	@coffee -o lib -c src/*.coffee

example:
	cd examples; node example.js

test1:
	@./node_modules/mocha/bin/mocha --compilers coffee:coffee-script test/*

test: test1
