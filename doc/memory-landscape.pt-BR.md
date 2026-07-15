# Paisagem de Memória

Data: 2026-03-17

Este documento resume os sistemas de memória referenciados na tarefa `PAP-530` e extrai os padrões de design que são importantes para o Paperclip.

## O Que o Paperclip Precisa Deste Estudo

O Paperclip não está tentando se tornar um motor de memória opinativo único. O alvo mais útil é uma superfície de memória do plano de controle que:

- permaneça no escopo da empresa
- permita que cada empresa escolha um provedor de memória padrão
- permita que agentes específicos anulem esse padrão
- mantenha a rastreabilidade até as execuções, issues, comentários e documentos do Paperclip
- registre o custo e a latência relacionados à memória da mesma forma que o resto do plano de controle registra o trabalho
- funcione com provedores fornecidos por plugins, não apenas internos

A pergunta não é "qual projeto de memória vence?" A pergunta é "qual é o contrato mais pequeno do Paperclip que pode ficar acima de vários sistemas de memória muito diferentes sem suprimir as diferenças úteis?".

## Agrupamento Rápido
### APIs de memória hospedadas

- `mem0`
- `AWS Bedrock AgentCore Memory`
- `supermemory`
- `Memori`

Estes otimizam para uma história de integração de aplicativos simples: enviar conversa/conteúdo mais uma identidade, então consultar a memória ou contexto do usuário relevante posteriormente.

### Frameworks/Sistemas Operacionais de Memória centrados em Agentes

- `MemOS`
- `memU`
- `EverMemOS`
- `OpenViking`

Estes tratam a memória como um subsistema de tempo de execução do agente, não apenas como um índice de pesquisa. Normalmente, eles adicionam memória de tarefa, perfis, organização em estilo de sistema de arquivos, ingestão assíncrona ou gerenciamento de habilidades/recursos.

### Armazéns de Memória "first local" / Índices

- `nuggets`
- `memsearch`

Estes enfatizam persistência local, inspeabilidade e baixa sobrecarga operacional. Eles são úteis porque o Paperclip é "first local" hoje e precisa de pelo menos um caminho sem configuração.

## Notas Por Projeto

| Projeto | Forma | API/Modelo Notável | Bom ajuste para Paperclip | Principal desalinhamento |
|---|---|---|---|---|
| [nuggets](https://github.com/NeoVertex1/nuggets) | motor de memória local + gateway de mensagem | memória de tópico com `remember`, `recall`, `forget`, promoção de fatos em `MEMORY.md` | bom exemplo de memória local leve e promoção automática | arquitetura muito específica; não um serviço multi-tenant geral |
| [mem0](https://github.com/mem0ai/mem0) | hospedado + SDK OSS | `add`, `search`, `getAll`, `get`, `update`, `delete`, `deleteAll`; particionamento de entidade via `user_id`, `agent_id`, `run_id`, `app_id` | mais próximo de uma API de provedor limpa com identidades e filtros de metadados | o provedor assume fortemente a extração; o Paperclip não deve presumir que todos os backends se comportam como o mem0 |
| [AWS Bedrock AgentCore Memory](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/memory.html) | serviço de memória gerenciado pela AWS | memórias de curto e longo prazo explícitas, APIs de ator/sessão/evento, estratégias de memória, modelos de namespace, pipeline de extração autogerenciado opcional | forte exemplo de memória gerenciada pelo provedor com IDs e controles de retenção escopados claros e acesso à API independente fora de um único framework de agente | hospedado na AWS e centrado no IAM; o Paperclip ainda precisaria de sua própria rastreabilidade para empresa/execução/comentário, agregações de custos e provavelmente um wrapper de plugin em vez de incorporar a semântica da AWS no núcleo |
| [MemOS](https://github.com/MemTensor/MemOS) | sistema operacional de memória / framework | adicionar-recuperar-editar-excluir unificado, cubos de memória, memória multimodal, memória de ferramenta, agendador assíncrono, feedback/correção | forte fonte para capacidades opcionais além da pesquisa simples | muito mais amplo do que o contrato mínimo que o Paperclip deve padronizar primeiro |
| [supermemory](https://github.com/supermemoryai/supermemory) | memória hospedada + API de contexto | `add`, `profile`, `search.memories`, `search.documents`, upload de documentos, configurações; construção e esquecimento de perfis automáticos | forte exemplo de "bundle de contexto" em vez de resultados de pesquisa brutos | fortemente produzido ao redor da sua própria ontologia e fluxo hospedado |
| [memU](https://github.com/NevaMind-AI/memU) | framework de memória proativo para agentes | metáfora do sistema de arquivos, loop proativo, previsão de intenção, modelo companheiro sempre ativo | bom recurso quando a memória deve acionar o comportamento do agente, e não apenas recuperação | o enquadramento de assistente proativo é mais amplo do que o plano de controle de tarefa do Paperclip |
| [Memori](https://github.com/MemoriLabs/Memori) | tecido de memória hospedado + wrappers de SDK | registra contra LLM SDKs, atribuição via `entity_id` + `process_id`, sessões, nuvem + BYODB | forte exemplo de captura automática ao redor de clientes do modelo | o design centrado em wrapper não mapeia 1:1 com a vida útil Paperclip / issue / comentário |
| [EverMemOS](https://github.com/EverMind-AI/EverMemOS) | sistema de memória de longo prazo conversacional | Extração MemCell, narrativas estruturadas, perfis de usuário, recuperação híbrida / reclassificação | modelo útil para memórias estruturadas e em evolução com rastreabilidade de provenance | focado na memória conversacional em vez de eventos de plano de controle generalizado |
| [memsearch](https://github.com/zilliztech/memsearch) | índice de memória local "first markdown" | Markdown como verdade, `index`, `search`, `watch`, parsing de transcrições, hooks de plugin | excelente baseline para um provedor interno e inspeável com provenance | intencionalmente simples; sem semântica de serviço hospedado ou fluxo de correção rico |
| [OpenViking](https://github.com/volcengine/OpenViking) | banco de contexto | organização em estilo de sistema de arquivos das memórias/recursos/habilidades, carregamento em camadas, trajetória de recuperação visualizada | forte fonte para UX de navegação/inspect e provenance de contexto | trata o "banco de contexto" como um produto maior do que o Paperclip deve possuir |

## Primitivas Comuns No Paisagem
Mesmo que os sistemas discordem sobre a arquitetura, eles convergem em algumas primitivas:

- `ingest`: adicionar memória de texto, mensagens, documentos ou transcrições.
- `query`: pesquisar ou recuperar a memória dada uma tarefa, pergunta ou escopo.
- `scope`: particionar a memória por usuário, agente, projeto, processo ou sessão.
- `provenance`: transportar metadados suficientes para explicar de onde veio a memória.
- `maintenance`: atualizar, esquecer, depurar, compactar ou corrigir as memórias ao longo do tempo.
- `context assembly`: transformar memórias brutas em um pacote pronto para o agente.

Se o Paperclip não expor isso, ele não se adaptará bem aos sistemas acima.

## Onde Os Sistemas Divergem
São essas as diferenças que fazem com que o Paperclip precise de um contrato em camadas em vez de um motor único e rígido.

### 1. Quem é responsável pela extração?
- `mem0`, `supermemory` e `Memori` esperam que o provedor infira memórias das conversas.
- O `AWS Bedrock AgentCore Memory` suporta extração gerenciada pelo provedor e pipelines de extração autogerenciados onde o host escreve registros de memória de longo prazo, mas com controle.
- `memsearch` espera que o host decida o que escrever em Markdown, então indexe.
- `MemOS`, `memU`, `EverMemOS` e `OpenViking` estão em algum lugar entre, frequentemente expondo pipelines mais ricos de construção de memória.

O Paperclip deve suportar:
- extração gerenciada pelo provedor
- extração gerenciada pelo Paperclip com armazenamento/recuperação gerenciados pelo provedor
### 2. Qual é a fonte de verdade?
- `memsearch` e `nuggets` tornam a fonte inspecionável no disco.
- APIs hospedadas frequentemente fazem o provedor armazenar a versão canônica.
- Sistemas em estilo de sistema de arquivos como `OpenViking` e `memU` tratam a própria hierarquia como parte do modelo de memória.

O Paperclip não deve exigir uma forma de armazenamento única. Deve exigir referências normalizadas de volta para as entidades do Paperclip.
### 3. A memória é apenas pesquisa, ou também perfil e planejamento?
- `mem0` e `memsearch` são centrados na pesquisa e CRUD.
- `supermemory` adiciona perfis como uma saída primeira classe.
- `MemOS`, `memU`, `EverMemOS` e `OpenViking` expandem para memória de tarefa, perfis, organização em estilo de sistema de arquivos, ingestão assíncrona ou gerenciamento de habilidades/recursos.

O Paperclip deve tornar a pesquisa simples o contrato mínimo e capacidades mais ricas opcionais.
### 4. A memória é síncrona ou assíncrona?
- ferramentas locais frequentemente funcionam de forma síncrona no processo.
- `AWS Bedrock AgentCore Memory` é síncrono na borda da API, mas seu caminho de memória de longo prazo inclui comportamento de extração/indexação em segundo plano e políticas de retenção gerenciadas pelo provedor.
- sistemas maiores adicionam agendadores, indexação assíncrona, compactação ou trabalhos de sincronização.

O Paperclip precisa de operações de solicitação/resposta diretas e anexos de manutenção em segundo plano.

## Implicações Específicas Para O Paperclip
### O Paperclip deve possuir essas preocupações:
- vincular um provedor a uma empresa e, opcionalmente, anular no agente
- mapear entidades do Paperclip para escopos do provedor
- rastreabilidade de volta às issues, comentários, documentos e execuções do Paperclip
- relatórios de custo / token / latência para o trabalho de memória
- superfícies de navegação e inspeção na UI do Paperclip
- governança em operações destrutivas

### Os provedores devem possuir essas preocupações:
- heurísticas de extração
- estratégia de indexação/incorporação
- classificação e reclassificação
- síntese de perfil
- resolução de contradições e lógica de esquecimento
- detalhes do motor de armazenamento

### A superfície de controle deve permanecer pequena
O Paperclip não precisa padronizar todos os recursos de cada provedor. Ele precisa:
- um núcleo portátil essencial
- flags de capacidade opcionais para provedores mais ricos
- uma maneira de registrar IDs e metadados do provedor sem fingir que todos os provedores são internamente equivalentes

## Direção Recomendada
O Paperclip deve adotar um modelo de memória em duas camadas:

1. `Camada de vinculação de provedor + controle`
   O Paperclip decide qual chave de provedor está ativa para uma empresa, agente ou projeto e registra cada operação de memória com rastreabilidade e uso.

2. `Adaptador de provedor camada`
   Um adaptador embutido ou fornecido por plugin transforma as solicitações de memória do Paperclip em chamadas específicas do provedor.

O núcleo portátil deve cobrir:
- ingestão/gravação
- pesquisa/recuperação
- navegação/inspeção
- obter pelo identificador do provedor
- esquecer/correção
- relatórios de uso

As capacidades opcionais podem abranger:
- síntese de perfil
- ingestão assíncrona
- conteúdo multimodal
- memória de ferramenta / recurso / habilidade
- navegação e inspeção nativa do provedor

Isso é suficiente para suportar:
- uma baseline local em Markdown semelhante ao `memsearch`
- serviços hospedados semelhantes a `mem0`, `supermemory` ou `Memori`
- sistemas de memória mais ricos, como `MemOS` ou `OpenViking`

sem forçar o próprio Paperclip a se tornar um motor de memória monolítico.
