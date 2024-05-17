#!/usr/bin/env node
var esprima = require('esprima');
var program = require('commander');
var fs = require('fs')

program.usage('tojson FILE.js')
program.parse(process.argv)

if (program.args.length === 0)
	program.help();

var file = program.args[0];
var text = fs.readFileSync(file, 'utf8');
var ast = esprima.parse(text, {'range':false})

console.log(JSON.stringify(ast))

