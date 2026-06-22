const cp = require('child_process');
const cmd = ['node -e', JSON.stringify("console.log('ok')")].join(' ');
cp.exec(`C:\\Program Files\\Git\\bin\\sh.exe -c ${JSON.stringify(cmd)}`, (err, stdout, stderr) => console.log({err, stdout, stderr}));
