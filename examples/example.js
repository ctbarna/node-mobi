fs = require('fs');
Mobi = require('mobi');

var book = new Mobi(process.argv[2]);
console.log(book.mobiHeader);
fs.writeFileSync('test.html', book.content);

