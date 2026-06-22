const fs = require('fs');
let content = fs.readFileSync('../scripts/provision-worktree.sh', 'utf8');

content = content.replace(
  /"PAPERCLIP_HOME=" \+ JSON\.stringify\(worktreeHome\)/g,
  '"PAPERCLIP_HOME=\\"" + worktreeHome.replace(/\\\\/g, "/") + "\\""'
);
content = content.replace(
  /"PAPERCLIP_INSTANCE_ID=" \+ JSON\.stringify\(instanceId\)/g,
  '"PAPERCLIP_INSTANCE_ID=\\"" + instanceId.replace(/\\\\/g, "/") + "\\""'
);
content = content.replace(
  /"PAPERCLIP_CONFIG=" \+ JSON\.stringify\(configPath\)/g,
  '"PAPERCLIP_CONFIG=\\"" + configPath.replace(/\\\\/g, "/") + "\\""'
);
content = content.replace(
  /"PAPERCLIP_CONTEXT=" \+ JSON\.stringify\(path\.resolve\(worktreeHome, "context\.json"\)\)/g,
  '"PAPERCLIP_CONTEXT=\\"" + path.resolve(worktreeHome, "context.json").replace(/\\\\/g, "/") + "\\""'
);
content = content.replace(
  /"PAPERCLIP_WORKTREE_NAME=" \+ JSON\.stringify\(worktreeName\)/g,
  '"PAPERCLIP_WORKTREE_NAME=\\"" + worktreeName.replace(/\\\\/g, "/") + "\\""'
);

fs.writeFileSync('../scripts/provision-worktree.sh', content);
