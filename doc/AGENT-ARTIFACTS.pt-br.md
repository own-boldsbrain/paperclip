# Fluxo de Upload de Artefatos do Agente

Os arquivos gerados que um usuário ou revisor da plataforma deve inspecionar como entregas, devem ser anexados ao problema "Paperclip" antes que o agente escolha a disposição final. Um caminho de espaço de trabalho local não é suficiente, porque usuários e revisores na nuvem frequentemente não conseguem acessar o disco do agente.

Use o utilitário fornecido com a habilidade Paperclip da raiz do repositório:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh path/to/output.webm \
  --title "Renderização para revisão" \
  --summary "Renderização para revisão"
```

O utilitário usa a API Paperclip autenticada do ambiente de heartbeat atual:

- `PAPERCLIP_API_URL`
- `PAPERCLIP_API_KEY`
- `PAPERCLIP_COMPANY_ID`
- `PAPERCLIP_TASK_ID`
- `PAPERCLIP_RUN_ID`

Ele envia o arquivo para
`POST /api/companies/{companyId}/issues/{issueId}/attachments` e cria um
produto de trabalho do artefato em `POST /api/issues/{issueId}/work-products` por padrão.
O comando imprime links Markdown seguros para o comentário da tarefa final.

## Artefatos Enviados vs Arquivos do Workspace

Use os artefatos enviados para as entregas: vídeos, PDFs, capturas de tela, arquivos compactados, relatórios, HTML renderizado ou qualquer arquivo que a plataforma deva inspecionar sem precisar do checkout do agente. Produtos de trabalho do artefato com anexos definem `type` para
`artifact` e `provider` para `paperclip`, com metadados canonizados a partir
do `attachmentId` enviado.

Use apenas os metadados `workspace_file` apenas para arquivos importantes que são intencionalmente mantidos em um espaço de trabalho de projeto ou execução, como arquivos de origem, planos Markdown confirmados ou arquivos gerados cujo significado depende do checkout. Referências apenas do workspace são indicadores úteis, mas não são uploads duráveis.

Forma esperada de metadados do produto de trabalho:

```json
{
  "resourceRef": {
    "kind": "workspace_file",
    "issueId": "<issue-id>",
    "workspaceKind": "execution_workspace",
    "workspaceId": "<execution-workspace-id>",
    "relativePath": "doc/plans/example.md",
    "line": 1,
    "column": 1,
    "displayPath": "doc/plans/example.md:1:1"
  }
}
```

`workspaceKind` é `execution_workspace` ou `project_workspace`. `line` e
`column` são opcionais. `relativePath` deve ser relativo à raiz desse workspace;
não armazene caminhos absolutos locais como referências de workspace.

Os links de arquivo do workspace só resolvem dentro dos workspaces Paperclip registrados.
O alvo padrão é primeiro o workspace de execução da questão atual, e depois seu
workspace de projeto. Um link pode direcionar para outro mesmo projeto na mesma empresa apenas quando carrega tanto `projectId` quanto `workspaceId`. O Paperclip não
resolve caminhos de sistema de arquivos arbitrários em nível de máquina, caminhos absolutos, caminhos home ou caminhos relativos que escapam do workspace selecionado.

## Padrão de Conclusão

Quando uma tarefa produz um arquivo de entrega que pode ser inspecionado pelo usuário:

1. Gere e verifique o arquivo localmente.
2. Envie-o usando `skills/paperclip/scripts/paperclip-upload-artifact.sh`.
3. Mantenha o produto de trabalho do artefato, a menos que o arquivo seja incidental; use `--no-work-product` apenas para arquivos de suporte que não devem ser promovidos.
4. Crie um link com o URL de anexação impresso no comentário final da questão.
5. Em seguida, defina o status final da questão.

Os comentários finais devem nomear e vincular ao artefato ou produto de trabalho carregado, em vez de apenas o caminho do sistema de arquivos local. Para arquivos apenas do workspace, inclua o título do produto de trabalho e o caminho relativo registrado. Caminhos locais podem ser incluídos como contexto diagnóstico, mas não podem ser a única via de acesso. Navegação/busca é uma
alternativa para recuperar arquivos do workspace quando o link da questão ou chip não está disponível, não é a maneira preferida de fornecer arquivos para os usuários.

## Exemplos de Vídeos

Envie um render `.mp4`:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh dist/demo.mp4 \
  --title "Renderização do vídeo de demonstração" \
  --summary "Renderização MP4 para revisão da plataforma"
```

Envie um render `.webm`:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh out/walkthrough.webm \
  --title "Vídeo de walkthrough" \
  --summary "Renderização de walkthrough WebM"
```

O utilitário detecta os tipos de conteúdo `.mp4`, `.webm` e `.mov`. Se um renderizador usar uma extensão incomum, passe o tipo MIME explicitamente:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh render.bin \
  --title "Renderização do vídeo de demonstração" \
  --content-type video/mp4
```

## Padrão de API Direto

Se o utilitário não estiver disponível, use a mesma forma de API:

```sh
curl -sS -X POST \
  "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues/$PAPERCLIP_TASK_ID/attachments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -F 'file=@"dist/demo.mp4";type=video/mp4'
```

Em seguida, crie um produto de trabalho quando o arquivo carregado for a entrega:

```sh
curl -sS -X POST \
  "$PAPERCLIP_API_URL/api/issues/$PAPERCLIP_TASK_ID/work-products" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  --data-binary @artifact-work-product.json
```

Use `type: "artifact"`, `provider: "paperclip"`, e metadados contendo o
`attachmentId` enviado. O servidor canoniza `contentType`, `byteSize`,
`contentPath`, `openPath`, `downloadPath` e `originalFilename`.

