fs = require('fs');
Mobi = require('mobi');

var book = new Mobi('pg1342.mobi');
console.log(book.mobiHeader);
fs.writeFileSync('test.html', book.content);

