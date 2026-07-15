# Fluxo de Upload de Artefatos do Agente

Os arquivos gerados que um usuário ou revisor da placa devem inspecionar como entregáveis
devem ser anexados ao problema Paperclip antes que o agente escolha uma
disposição final. Um caminho de espaço de trabalho local não é suficiente, porque usuários e
revisores na nuvem frequentemente não podem acessar o disco do agente.

Use o utilitário fornecido com a habilidade Paperclip da raiz do repositório:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh path/to/output.webm \
  --title "Renderização de walkthrough" \
  --summary "Renderização de walkthrough para revisão"
```

O utilitário usa a API Paperclip autenticada do ambiente atual:

- `PAPERCLIP_API_URL`
- `PAPERCLIP_API_KEY`
- `PAPERCLIP_COMPANY_ID`
- `PAPERCLIP_TASK_ID`
- `PAPERCLIP_RUN_ID`

Ele envia o arquivo para
`POST /api/companies/{companyId}/issues/{issueId}/attachments` e cria um
produto de trabalho de artefato em `POST /api/issues/{issueId}/work-products` por padrão.
O comando imprime links Markdown seguros para o comentário da tarefa final.

## Artefatos Enviados vs Arquivos do Workspace

Use artefatos enviados para entregáveis: vídeos, PDFs, capturas de tela, arquivos compactados,
relatórios, HTML renderizado ou qualquer arquivo que a placa deva inspecionar sem precisar da
verificação do agente. Produtos de trabalho de artefato com anexos definem `type` para
`artifact` e `provider` para `paperclip`, com metadados canonizados a partir do
`attachmentId` enviado.

Use apenas os metadados `workspace_file` para arquivos importantes que são intencionalmente mantidos em um projeto ou workspace de execução, como arquivos de origem, planos Markdown confirmados ou arquivos gerados cujo significado depende da verificação. Referências somente no workspace são sinais úteis, mas não são uploads duradouros.

Formato esperado dos metadados do produto de trabalho:

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
`column` são opcionais. `relativePath` deve ser relativo à raiz do workspace;
não armazene caminhos absolutos locais como referências de workspace.

Os links dos arquivos do workspace só se resolvem dentro dos workspaces Paperclip registrados.
O alvo padrão é primeiro o workspace de execução da issue atual, e então seu
workspace de projeto. Um link pode direcionar outro workspace de projeto da mesma empresa somente quando ele carrega tanto o `projectId` quanto o `workspaceId`. O Paperclip não
resolve caminhos arbitrários do sistema de arquivos em toda a máquina, caminhos absolutos do host, caminhos home ou caminhos relativos que escapam do workspace selecionado.

## Padrão de Conclusão

Quando uma tarefa produz um arquivo entregável para inspeção do usuário:

1. Gere e verifique o arquivo localmente.
2. Envie-o usando `skills/paperclip/scripts/paperclip-upload-artifact.sh`.
3. Mantenha o produto de trabalho de artefato a menos que o arquivo seja incidental; apenas passe `--no-work-product` para arquivos de suporte que não devem ser promovidos.
4. Crie um link para a URL de anexação impressa no comentário da issue final.
5. Em seguida, defina o status final da issue.

Os comentários finais devem nomear e vincular o artefato ou produto de trabalho enviado, em vez
apenas do caminho do sistema de arquivos local. Para arquivos somente no workspace, inclua o título do produto de trabalho e o caminho relativo gravado. Caminhos locais podem ser incluídos como
contexto diagnóstico, mas não podem ser a única via de acesso. A navegação/pesquisa é um
fallback para recuperar arquivos do workspace quando o link ou chip da issue não estão
disponíveis, não é a maneira preferida de entregar arquivos aos usuários.

## Exemplos de Vídeos

Envie um render `.mp4`:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh dist/demo.mp4 \
  --title "Renderização de vídeo demo" \
  --summary "Renderizado MP4 para revisão do conselho"
```

Envie um render `.webm`:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh out/walkthrough.webm \
  --title "Vídeo de walkthrough" \
  --summary "Renderização de vídeo WebM"
```

O utilitário detecta tipos de conteúdo `.mp4`, `.webm` e `.mov`. Se um renderizador usar uma extensão incomum, passe o tipo MIME explicitamente:

```sh
skills/paperclip/scripts/paperclip-upload-artifact.sh render.bin \
  --title "Renderização de vídeo demo" \
  --content-type video/mp4
```

## Padrão API Direto

Se o utilitário não estiver disponível, use a mesma forma da API:

```sh
curl -sS -X POST \
  "$PAPERCLIP_API_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues/$PAPERCLIP_TASK_ID/attachments" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -F 'file=@"dist/demo.mp4";type=video/mp4'
```

Em seguida, crie um produto de trabalho quando o arquivo enviado é o entregável:

```sh
curl -sS -X POST \
  "$PAPERCLIP_API_URL/api/issues/$PAPERCLIP_TASK_ID/work-products" \
  -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
  -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
  -H "Content-Type: application/json" \
  --data-binary @artifact-work-product.json
```

Use `type: "artifact"`, `provider: "paperclip"` e metadados contendo o
`attachmentId` enviado. O servidor canoniza `contentType`, `byteSize`,
`contentPath`, `openPath`, `downloadPath` e `originalFilename`.
