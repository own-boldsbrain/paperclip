const { spawn } = require('child_process');
const p = spawn('C:\\Program Files\\Git\\bin\\sh.exe', ['-c', 'node -e "require(\'node:http\').createServer((req,res)=>res.end(\'ok\')).listen(12345, \'127.0.0.1\')"']);
console.log('sh.exe PID:', p.pid);

setTimeout(() => {
  const { execSync } = require('child_process');
  try {
    execSync('C:\\Windows\\System32\\taskkill.exe /pid ' + p.pid + ' /t /f', { stdio: 'inherit' });
    console.log('Taskkill success');
  } catch (e) {
    console.error('Taskkill failed');
  }
}, 2000);
