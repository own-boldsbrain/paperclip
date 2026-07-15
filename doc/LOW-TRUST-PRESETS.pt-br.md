# Predefinições de Confiança Baixa

O Paperclip envia nomes padrão das predefinições de confiança para que as decisões de contenção sejam aplicadas na
edição Community, mesmo quando a edição da política EE não está disponível.

## Predefinições

- `standard`: o modelo padrão de colaboração visível pela empresa V1. Isso preserva
  o comportamento existente para agentes normais.
- `low_trust_review`: uma predefinição de contenção opcional para trabalhos automatizados que podem
  consumir entradas hostis ou injetadas, como solicitações pull não confiáveis,
  tickets externos, diferenças de dependências ou saída gerada de revisão.

## Modelo de Borda

`low_trust_review` é definido a partir dos campos de política JSON existentes:

- permissões do agente: `permissions.trustPreset` e
  `permissions.authorizationPolicy.trustBoundary`
- política do projeto:
  `executionWorkspacePolicy.authorizationPolicy.trustBoundary`
- política de issue/run: `executionPolicy.authorizationPolicy.trustBoundary`

O resolvedor intercala essas fontes. A restrição mais estreita prevalece. Uma predefinição de confiança baixa deve
resolver para um projeto local da empresa, issue raiz ou escopo de ID de issue específico. Se uma
fonte de política se refere a outra empresa, usa uma predefinição não suportada ou carece desse
escopo para acesso arriscado, o Paperclip falha na contenção.

## Contenção, Não Privacidade

Este é um sistema de contenção para trabalhos automatizados hostis. Não é um sistema geral de privacidade para projetos,
issues ou humanos.

O trabalho padrão V1 permanece visível pela empresa por padrão: os usuários da board e os atores dentro da empresa podem inspecionar objetos de trabalho da empresa, a menos que uma funcionalidade separada de controle de acesso altere esse comportamento. A contenção de confiança baixa, em vez disso, limita o que o agente de confiança baixa pode ler ou modificar através da API Paperclip e impede que saídas brutas não confiáveis sejam automaticamente promovidas para um contexto de agente de confiança mais alta.

## Contenção em Tempo de Execução

Execuções gerenciadas `low_trust_review` falham se o Paperclip não puder impor a
borda em tempo de execução:

- o ambiente de execução selecionado deve usar o driver `sandbox`
- o modo do workspace de execução efetivo deve ser `isolated_workspace`
- a issue que está sendo executada deve estar dentro da borda de confiança baixa resolvida
- referências secretas devem usar IDs vinculados explicitamente permitidos pela borda
- valores de ambiente sensíveis inline, como chaves de API e tokens, são rejeitados
- mutações do serviço runtime do workspace são negadas, a menos que a borda conceda explicitamente à classe de ferramenta `runtime.manage`

O fluxo de trabalho Docker em `doc/UNTRUSTED-PR-REVIEW.md` permanece útil para revisão local manual, mas a execução de confiança baixa gerenciada pelo Paperclip requer um
ambiente sandboxed em vez de um processo de adaptador local do host.
