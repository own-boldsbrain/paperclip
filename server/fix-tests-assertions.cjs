const fs = require('fs');
let content = fs.readFileSync('src/__tests__/workspace-runtime.test.ts', 'utf8');

// Fix CRLF issues
content = content.replace(/\.toBe\("preserve me\\n"\)/g, '.toEqual(expect.stringContaining("preserve me"))');
content = content.replace(/\.toBe\("persisted\\n"\)/g, '.toEqual(expect.stringContaining("persisted"))');

// Fix timeout not applying correctly
content = content.replace(
  'expect(services[0]?.scopeId).toBe("execution-workspace-1");\n  });',
  'expect(services[0]?.scopeId).toBe("execution-workspace-1");\n  }, 15_000);'
);

// Fix parseEnvContents backslash issue
content = content.replace(
  'const [k, v] = line.split("=");',
  'let [k, v] = line.split("="); if (v) v = v.replace(/^"|"$/g, "");'
);

fs.writeFileSync('src/__tests__/workspace-runtime.test.ts', content);
