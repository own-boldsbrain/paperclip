const fs = require('fs');
let content = fs.readFileSync('src/__tests__/workspace-runtime.test.ts', 'utf8');
content = content.replace(
  'await execFileAsync("pnpm", args, { cwd });',
  'await execFileAsync(process.platform === "win32" ? "pnpm.cmd" : "pnpm", args, { cwd });'
);
fs.writeFileSync('src/__tests__/workspace-runtime.test.ts', content);
