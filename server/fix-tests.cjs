const fs = require('fs');
let content = fs.readFileSync('src/__tests__/worktree-config.test.ts', 'utf8');
content = content.replaceAll('=${JSON.stringify(isolatedHome)}', '="${isolatedHome}"');
content = content.replaceAll('=${JSON.stringify(instanceId)}', '="${instanceId}"');
content = content.replaceAll('=${JSON.stringify(configPath)}', '="${configPath}"');
content = content.replaceAll('=${JSON.stringify(path.join(isolatedHome, "context.json"))}', '="${path.join(isolatedHome, "context.json")}"');
fs.writeFileSync('src/__tests__/worktree-config.test.ts', content);
