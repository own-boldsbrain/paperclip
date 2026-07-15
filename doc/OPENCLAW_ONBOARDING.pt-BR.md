Use esta lista de verificação exata.

1. Inicie o Paperclip no modo de autenticação.

```bash
cd <paperclip-repo-root>
pnpm dev --bind lan
```

Em seguida, verifique:

```bash
curl -sS http://127.0.0.1:3100/api/health | jq
```

1. Inicie um OpenClaw Docker limpo/padrão.

```bash
OPENCLAW_RESET_STATE=1 OPENCLAW_BUILD=1 ./scripts/smoke/openclaw-docker-ui.sh
```

Abra o URL do `Dashboard` impresso (incluindo `#token=...`) no seu navegador.

1. Na interface do Paperclip, vá para `http://127.0.0.1:3100/CLA/company/settings`.

2. Use o fluxo de convite do OpenClaw.

- Na seção "Convites", clique em `Generate OpenClaw Invite Prompt`.
- Copie o prompt gerado de `OpenClaw Invite Prompt`.
- Cole-o no chat principal do OpenClaw como uma mensagem.
- Se ficar travado, envie um acompanhamento: `How is onboarding going? Continue setup now.`

Observação de segurança/controle:

- O prompt de convite do OpenClaw é criado a partir de um ponto final controlado:
  - `POST /api/companies/{companyId}/openclaw/invite-prompt`
  - usuários da board com permissão de convite podem chamá-lo
  - agentes chamadores são limitados ao CEO da empresa

1. Aprovando o pedido de adesão na interface do Paperclip, confirme que o agente OpenClaw aparece nos agentes CLA.

2. Pré-visto do gateway (requerido antes dos testes de tarefa).

- Confirme se o agente criado usa `openclaw_gateway` (não `openclaw`).
- Confirme se a URL do gateway é `ws://...` ou `wss://...`.
- Confirme se o token do gateway não é trivial (não vazio / não placeholder de 1 caractere).
- A interface do adaptador OpenClaw Gateway não deve expor `disableDeviceAuth` para onboarding normal.
- Confirme se o modo de pareamento é explícito:
  - opção padrão requerida: autenticação de dispositivo habilitada (`adapterConfig.disableDeviceAuth` false/ausente) com chave privada de dispositivo persistida `adapterConfig.devicePrivateKeyPem`
  - não confie em `disableDeviceAuth` para onboarding normal
- Se você conseguir executar verificações de API com autenticação da board:

```bash
AGENT_ID="<newly-created-agent-id>"
curl -sS -H "Cookie: $PAPERCLIP_COOKIE" "http://127.0.0.1:3100/api/agents/$AGENT_ID" | jq '{adapterType,adapterConfig:{url:.adapterConfig.url,tokenLen:(.adapterConfig.headers["x-openclaw-token"] // .adapterConfig.headers["x-openclaw-auth"] // "" | length),disableDeviceAuth:(.adapterConfig.disableDeviceAuth // false),hasDeviceKey:(.adapterConfig.devicePrivateKeyPem // "" | length > 0)}}'
```

- Esperado: `adapterType=openclaw_gateway`, `tokenLen >= 16`, `hasDeviceKey=true` e `disableDeviceAuth=false`.

Observação sobre o "handshake" de pareamento:

- Expectativa de execução limpa: a primeira tarefa deve ter sucesso sem comandos de pareamento manuais.
- O adaptador tenta uma aprovação automática + retry na primeira vez que é necessário (quando o token/senha de autenticação do gateway compartilhado é válido).
- Se a auto-pair não conseguir completar (por exemplo, incompatibilidade do token ou nenhuma solicitação pendente), a primeira execução do gateway ainda pode retornar "necessário pareamento".
- Este é um aprovação separado da aprovação do convite do Paperclip. Você deve aprovar o dispositivo pendente no OpenClaw.
- Aprová-lo no OpenClaw, e então retentar a tarefa.
- Para o smoke local do Docker, você pode aprovar a partir do host:

```bash
docker exec openclaw-docker-openclaw-gateway-1 sh -lc 'openclaw devices approve --latest --json --url "ws://127.0.0.1:18789" --token "$(node -p \"require(process.env.HOME+\\\"/.openclaw/openclaw.json\\\").gateway.auth.token\")"'
```

- Você pode inspecionar os dispositivos pendentes vs. pareados:

```bash
docker exec openclaw-docker-openclaw-gateway-1 sh -lc 'TOK="$(node -e \"const fs=require(\\\"fs\\\");const c=JSON.parse(fs.readFileSync(\\\"/home/node/.openclaw/openclaw.json\\\",\\\"utf8\\\");process.stdout.write(c.gateway?.auth?.token||\\\"\\\");\")\"; openclaw devices list --json --url \"ws://127.0.0.1:18789\" --token \"$TOK\"'
```

1. Caso A (teste de emissão manual).

- Crie uma tarefa atribuída ao agente OpenClaw.
- Coloque as instruções: "enviar comentário `OPENCLAW_CASE_A_OK_<timestamp>` e marcar como concluído".
- Verifique na interface do usuário: o status da tarefa se torna `done` e o comentário existe.

1. Caso B (teste de ferramenta de mensagem).

- Crie outra tarefa atribuída ao OpenClaw.
- Instruções: "enviar texto `OPENCLAW_CASE_B_OK_<timestamp>` para o chat principal via ferramenta de mensagem, depois marcar o mesmo marcador na tarefa, e marcar como concluído".
- Verifique ambos:
  - marcador no comentário da tarefa
  - o texto do marcador aparece no chat principal do OpenClaw

1. Caso C (memória/habilidades de sessão nova).

- No OpenClaw, inicie a sessão `/new`.
- Peça para ele criar uma nova tarefa no Paperclip com um título único `OPENCLAW_CASE_C_CREATED_<timestamp>`.
- Verifique na interface do Paperclip se a nova tarefa existe.

1. Monitore os logs durante o teste (opcional, mas útil):

```bash
docker compose -f /tmp/openclaw-docker/docker-compose.yml -f /tmp/openclaw-docker/.paperclip-openclaw.override.yml logs -f openclaw-gateway
```

1. Critérios de passagem esperados.

- Pré-visto: `openclaw_gateway` + token não placeholder (`tokenLen >= 16`).
- Modo de pareamento: `devicePrivateKeyPem` configurado com autenticação de dispositivo habilitada (caminho padrão) está estável.
- Caso A: `done` + comentário do marcador.
- Caso B: `done` + comentário do marcador + mensagem visível no chat principal.
- Caso C: tarefa original concluída e nova tarefa criada a partir da sessão `/new`.

Se quiser, posso também fornecer um único comando "observer mode" que executa o harness de smoke padrão enquanto você observa as mesmas etapas ao vivo na interface do usuário.
