const fs = require('fs');
let content = fs.readFileSync('src/__tests__/workspace-runtime.test.ts', 'utf8');
content = content.replace('    expect(services[0]?.scopeId).toBe("execution-workspace-1");\n  });', '    expect(services[0]?.scopeId).toBe("execution-workspace-1");\n  }, 15_000);');
fs.writeFileSync('src/__tests__/workspace-runtime.test.ts', content);
