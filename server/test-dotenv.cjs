const { parse } = require('dotenv');
console.log(parse('A="C:\\\\test\\\\path"').A === 'C:\\\\test\\\\path');
console.log(parse('A=C:\\test\\path').A === 'C:\\test\\path');
console.log(JSON.stringify('C:\\test\\path'));
