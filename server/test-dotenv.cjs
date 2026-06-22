const dotenv = require('dotenv');
console.log(dotenv.parse('A="C:\\\\test"').A);
console.log(dotenv.parse('B="C:\\test"').B);
