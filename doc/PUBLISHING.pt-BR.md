# Publicação no npm

Referência de baixo nível sobre como os pacotes Paperclip são preparados e publicados no npm.

Para o fluxo de trabalho do mantenedor, use [doc/RELEASING.md](RELEASING.md). Este documento se concentra nos detalhes de embalagem.

## Pontos de entrada de lançamento atuais

Use estes scripts:

- [`scripts/release.sh`](../scripts/release.sh) para fluxos de publicação canary e estáveis
- [`scripts/create-github-release.sh`](../scripts/create-github-release.sh) após o envio de uma tag estável
- [`scripts/rollback-latest.sh`](../scripts/rollback-latest.sh) para redefinir `latest`
- [`scripts/build-npm.sh`](../scripts/build-npm.sh) para a construção do pacote CLI

O Paperclip não usa mais ramos de lançamento ou Changesets para publicação.

## Por que o CLI precisa de embalagem especial

O pacote CLI, `paperclipai`, importa código de pacotes de workspace como:

- `@paperclipai/server`
- `@paperclipai/db`
- `@paperclipai/shared`
- pacotes de adaptador sob `packages/adapters/`

Essas referências de workspace são válidas no desenvolvimento, mas não em um pacote npm publicável. O fluxo de lançamento temporariamente reescreve as versões e, em seguida, constrói um pacote CLI publicável.

## `build-npm.sh`

Execute:

```bash
./scripts/build-npm.sh
```

Este script:

1. executa a verificação do token proibido, a menos que seja fornecido `--skip-checks`
2. executa `pnpm -r typecheck`
3. empacota o ponto de entrada CLI no esbuild para `cli/dist/index.js`
4. verifica o ponto de entrada empacotado com `node --check`
5. reescreve `cli/package.json` em um manifesto npm publicável e armazena a cópia de desenvolvimento como `cli/package.dev.json`
6. copia o arquivo README do repositório para `cli/README.md` para metadados npm

Após que o script de lançamento termine, as manifestações de desenvolvimento e os arquivos temporários são restaurados automaticamente.

## Descoberta e versionamento de pacotes

Pacotes públicos são descobertos a partir de:

- `packages/`
- `server/`
- `ui/`
- `cli/`

A etapa de reescrita da versão agora usa [`scripts/release-package-map.mjs`](../scripts/release-package-map.mjs), que:

- encontra todos os pacotes públicos
- os organiza topologicamente por dependências internas
- reescreve a versão do pacote para a versão de lançamento alvo
- reescreve as referências de dependência `workspace:*` internas para a versão alvo exata
- atualiza a string de versão exibida no CLI

Essas reescritas são temporárias. A árvore de trabalho é restaurada após a publicação ou simulação.

## Embalagem do `@paperclipai/ui`

O pacote UI publica ativos estáticos pré-construídos, e não o código fonte.
O pacote `ui` usa [`scripts/generate-ui-package-json.mjs`](../scripts/generate-ui-package-json.mjs) durante `prepack` para substituir por um manifesto de publicação enxuta que mantém:

- o nome e a versão gerenciados na versão de lançamento
- publica apenas `dist/`
- omite o grafo de dependência de origem apenas, das instalações downstream

Após empacotar ou publicar, `postpack` restaura automaticamente a manifestação de desenvolvimento.

### Primeira publicação manual para `@paperclipai/ui`

Se você precisar publicar o pacote UI uma única vez manualmente, use o nome do pacote real:

- `@paperclipai/ui`
Recomendado fluxo a partir da raiz do repositório:

```bash
# verificação opcional de sanidade: isso retorna 404 até que a primeira publicação exista
npm view @paperclipai/ui version

# certifique-se de que o payload dist seja fresco
pnpm --filter @paperclipai/ui build

# confirme seu npm auth local antes da publicação real
npm whoami

# visualização segura do payload publicado exato
cd ui
pnpm publish --dry-run --no-git-checks --access public

# publicação real
pnpm publish --no-git-checks --access public
```

Notas:

- Publique de `ui/`, não da raiz do repositório.
- `prepack` reescreve automaticamente o `ui/package.json` para o manifesto de publicação enxuta, e `postpack` restaura a manifestação de desenvolvimento após a conclusão do comando.
Se `npm view @paperclipai/ui version` já retorna a mesma versão que está em [`ui/package.json`](../ui/package.json), não publique novamente. Aumente a versão ou use o fluxo normal de lançamento do repositório em [`scripts/release.sh`](../scripts/release.sh).
Se a primeira publicação real retornar `npm E404`, verifique os pré-requisitos do npm antes de tentar novamente:
- `npm whoami` deve ter sucesso primeiro. Um login do npm expirado ou ausente bloqueará a publicação.
Para um pacote escopo de organização como `@paperclipai/ui`, a organização npm `paperclipai` deve existir e o publicador deve ser membro com permissão para publicar nesse escopo.
A primeira publicação deve incluir `--access public` para um pacote escopo público.
npm também requer autenticação 2FA ou um token granular que seja permitido contornar 2FA.

## Formatos de versão

O Paperclip usa versões calendáricas:

- estável: `YYYY.MM.P`
- canary: `YYYY.MM.P-canary.N`
Exemplo:
- estável: `2026.318.0`
- canary: `2026.318.1-canary.2`

## Modelo de publicação

### Canary

Os canaries publicam sob o dist-tag npm "canary".
Exemplo:

- `paperclipai@2026.318.1-canary.2`
Isso mantém o caminho de instalação padrão inalterado, enquanto permite instalações explícitas com:

```bash
npx paperclipai@canary onboard
```

O script de lançamento agora verifica duas coisas após a publicação canary:

- O dist-tag "canary" resolve para a versão que acabou de ser publicada
- Todas as dependências internas `@paperclipai/*` publicadas no manifesto existem no npm

Também trata `latest -> canary` como um erro por padrão, porque os metadados do npm podem deixar o caminho de instalação padrão apontando para um gráfico de dependência canary não lançado. Somente passe `./scripts/release.sh canary --allow-canary-latest` quando esse comportamento "latest" é explicitamente intencionado.

### Estável

As publicações estáveis usam o dist-tag npm "latest".
Exemplo:

- `paperclipai@2026.318.0`
As publicações estáveis não criam um commit de lançamento. Em vez disso:
- As versões do pacote são reescritas temporariamente
- Os pacotes são publicados a partir do commit de origem escolhido
- A tag git `vYYYY.MM.P` aponta para esse commit original

## Publicação confiável

O modelo de CI pretendido é a publicação confiável do npm através do GitHub OIDC.
Isso significa:

- Nenhum token longo vivo em segredos no repositório
- O GitHub Actions obtém credenciais de publicação de curto prazo
- As regras de publicador de confiança são configuradas nos arquivos de fluxo de trabalho

Veja [doc/RELEASE-AUTOMATION-SETUP.md](RELEASE-AUTOMATION-SETUP.md) para as etapas de configuração do GitHub/npm.

## Inscrição no lançamento para novos pacotes públicos

O Paperclip não publica mais automaticamente todos os pacotes de workspace não privados. A publicação CI é controlada por [`scripts/release-package-manifest.json`](../scripts/release-package-manifest.json).
Quando você adiciona um novo pacote público:

1. adicione-o ao manifesto e decida se a publicação CI deve ocorrer imediatamente
2. se a publicação CI deve ocorrer, inicialize o pacote no npm antes da mesclagem
3. se a publicação CI não deve ocorrer ainda, mantenha `"publishFromCi": false`
4. somente habilite `"publishFromCi": true` depois que a publicação confiável do npm para esse pacote estiver configurada
O fluxo PR de CI agora verifica os manifestos de lançamento alterados contra o npm. Isso detecta um bootstrap inicial ausente antes da alteração chegar ao `master`.

### Sequência de bootstrap única para um novo pacote

A primeira publicação de um novo pacote ainda requer um mantenedor humano com acesso de escrita ao npm. Após isso, a publicação confiável pode assumir o controle.
Exemplo para `@paperclipai/adapter-acpx-local` a partir da raiz do repositório:

```bash
# visualização segura
pnpm run release:bootstrap-package -- @paperclipai/adapter-acpx-local
# publicação única e primeira de um mantenedor autenticado
pnpm run release:bootstrap-package -- @paperclipai/adapter-acpx-local --publish --otp 123456
```

O script auxiliar:

- verifica se o pacote já existe no npm
- constrói o pacote alvo, a menos que seja fornecido `--skip-build`
- executa `npm pack --dry-run` no diretório do pacote
- executa apenas o comando `npm publish --access public` quando `--publish --otp <code>` é fornecido
Para a publicação real `--publish`, a máquina de desenvolvedor deve estar autenticada para o npm. Se `npm whoami` retorna `401`, primeiro execute `npm logout --registry=https://registry.npmjs.org/` para limpar qualquer autorização local, depois execute `npm login` ou `npm adduser` localmente como um membro do org npm e, finalmente, execute novamente o helper.
Essa autorização local é OK para a primeira publicação bootstrap; não queremos que o mesmo modelo de autorização esteja dentro do CI.
O helper agora requer `--otp <code>` no início para `--publish`, então ele falha antes de tentar a publicação real se o código OTP estiver faltando.

Após essa primeira publicação ter sucesso:

1. abra `https://www.npmjs.com/package/@paperclipai/adapter-acpx-local`
2. vá para "Configurações" -> "Publicação confiável"
3. adicione o repositório `paperclipai/paperclip`
4. defina o nome do arquivo de fluxo de trabalho para `release.yml`
5. opcionalmente, vá para "Configurações" -> "Acesso de publicação" e habilite "Requer autenticação 2FA e desabilita tokens"
6. mantenha `"publishFromCi": true` em [`scripts/release-package-manifest.json`](../scripts/release-package-manifest.json)

Depois que essas etapas forem concluídas, as publicações canary e estáveis para esse pacote serão automatizadas através do GitHub OIDC. O passo manual é apenas a primeira criação de pacote no npm.

## Modelo de reversão

A reversão não despublica nada.
Reaponta o dist-tag "latest" para uma versão estável anterior:

```bash
./scripts/rollback-latest.sh 2026.318.0
```

Este é a maneira mais rápida de restaurar o caminho de instalação padrão se uma versão estável for problemática.

## Arquivos relacionados

- [`scripts/build-npm.sh`](../scripts/build-npm.sh)
- [`scripts/generate-npm-package-json.mjs`](../scripts/generate-npm-package-json.mjs)
- [`scripts/generate-ui-package-json.mjs`](../scripts/generate-ui-package-json.mjs)
- [`scripts/release-package-map.mjs`](../scripts/release-package-map.mjs)
- [`cli/esbuild.config.mjs`](../cli/esbuild.config.mjs)
- [`doc/RELEASING.md`](RELEASING.md)
