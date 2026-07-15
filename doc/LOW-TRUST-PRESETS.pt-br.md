# Predefinições de Confiança Baixa

O Paperclip envia nomes padrão para as predefinições de confiança, de modo que as decisões de contenção sejam aplicadas na
edição da Comunidade, mesmo quando a edição da política EE não está disponível.

## Predefinições

- `standard`: o modelo padrão de colaboração visível pela empresa V1. Isso preserva
  o comportamento existente para agentes normais.
- `low_trust_review`: uma predefinição de contenção opcional para trabalho automatizado que pode
  consumir entradas hostis ou injetadas por prompts, como solicitações pull não confiáveis,
  tickets externos, diferenças de dependência ou saída de revisão gerada.

## Modelo de Borda

`low_trust_review` é resolvido a partir dos campos de política JSON existentes:

- permissões do agente: `permissions.trustPreset` e
  `permissions.authorizationPolicy.trustBoundary`
- política do projeto:
  `executionWorkspacePolicy.authorizationPolicy.trustBoundary`
- política da issue/run: `executionPolicy.authorizationPolicy.trustBoundary`

O resolvedor interseciona essas fontes. A mais restritiva prevalece. Uma predefinição de confiança baixa deve
resolver para um projeto local específico da empresa, uma issue raiz ou um escopo de ID de issue. Se uma
fonte de política se refere a outra empresa, usa uma predefinição não suportada ou carece desse
escopo para acesso arriscado, o Paperclip falha em concluir.

## Contenção, Não Privacidade

Este é sobre contenção para trabalho automatizado hostil. Não é um sistema geral de privacidade do projeto,
issue ou humano.

O trabalho padrão V1 permanece visível pela empresa por padrão: usuários e atores da empresa podem inspecionar objetos de trabalho da empresa, a menos que um recurso separado de controle de acesso altere esse comportamento. A contenção de confiança baixa, em vez disso, limita o que o agente de confiança baixa pode ler ou modificar através da API Paperclip e impede que a saída bruta não confiável seja promovida automaticamente para um contexto de agente de maior confiança.

## Contenção em Tempo de Execução

Execuções gerenciadas `low_trust_review` falham se o Paperclip não puder aplicar
a borda de tempo de execução:

- o ambiente de execução selecionado deve usar o driver `sandbox`
- o modo do workspace de execução efetivo deve ser `isolated_workspace`
- a issue em execução deve estar dentro da borda de confiança baixa resolvida
- referências secretas devem usar IDs de vinculação explicitamente permitidos pela borda
- valores de ambiente sensíveis inline, como chaves API e tokens, são rejeitados
- mutações de serviço de runtime do workspace são negadas, a menos que a borda conceda explicitamente a classe de ferramenta `runtime.manage`

O fluxo de trabalho Docker em `doc/UNTRUSTED-PR-REVIEW.md` permanece útil para revisão local manual, mas a execução Paperclip gerenciada de confiança baixa requer um ambiente contido
em vez de um processo adaptador local do host.
