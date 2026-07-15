# Modos de Implantação

Status: Modelo padrão de implantação e autenticação
Data: 2026-02-23

## 1. Propósito

O Paperclip suporta dois modos de tempo de execução:

1. `local_trusted`
2. `authenticated`

O `authenticated` suporta duas políticas de exposição:

1. `private`
2. `public`

Isso mantém um stack de autenticação autenticado, ao mesmo tempo em que separa os padrões predefinidos privados da rede de baixo atrito dos requisitos de segurança voltados para a internet.

Agora, o Paperclip trata o **bind** como uma preocupação separada do autenticador:

- modelo de autenticação: `local_trusted` vs `authenticated`, mais `private/public`
- modelo de acessibilidade: `server.bind = loopback | lan | tailnet | custom`

## 2. Modelo Padrão

| Modo de Tempo de Execução | Exposição | Autenticação Humana | Uso Primário |
|---|---|---|---|
| `local_trusted` | n/a | Sem login necessário | Fluxo de máquina local para um único operador |
| `authenticated` | `private` | Login necessário | Acesso à rede privada (por exemplo, Tailscale/VPN/LAN) |
| `authenticated` | `public` | Login necessário | Implantação voltada para a Internet/nuvem |

## 3. Modelo de Acessibilidade

| Bind | Significado | Uso Típico |
|---|---|---|
| `loopback` | Escuta apenas na localhost | Uso local padrão, implantações de proxy reverso |
| `lan` | Escuta em todas as interfaces (`0.0.0.0`) | Acesso LAN/VPN/rede privada |
| `tailnet` | Escuta em um endereço IP Tailscale detectado | Apenas acesso ao Tailscale |
| `custom` | Escuta em um host/IP explícito | Configurações específicas da interface avançadas |

## 4. Política de Segurança

## `local_trusted`

- vinculação de host apenas para loopback
- sem fluxo de login humano
- otimizado para o início mais rápido local

## `authenticated + privado`

- necessário login
- tratamento de URL com baixo atrito (`auto` modo de URL base)
- política de confiança do host privado necessária
- o bind pode ser `loopback`, `lan`, `tailnet` ou `custom`

## `authenticated + público`

- necessário login
- URL pública explícita necessária
- verificações e falhas mais rigorosas no "doctor"
- o bind recomendado é `loopback` atrás de um proxy reverso; `lan/custom` direto é avançado

## 5. Contrato UX para Onboarding

O onboarding padrão permanece interativo e sem flags:

```sh
pnpm paperclipai onboard
```

Comportamento do prompt do servidor:

1. `quickstart --yes` por padrão usa `server.bind=loopback` e, portanto, `local_trusted/private`
2. configuração avançada do servidor pergunta sobre a acessibilidade primeiro:
- `Trusted local` ? `bind=loopback`, `authenticated/private`
- `Private network` ? `bind=lan`, `authenticated/private`
- `Tailnet` ? `bind=tailnet`, `authenticated/private`
- `Custom` ? modo manual/configuração de exposição/entrada de host
3. a entrada de host bruta é necessária apenas para o caminho `Custom`
4. a URL pública explícita é necessária apenas para `authenticated + público`

Exemplos:

```sh
pnpm paperclipai onboard --yes
pnpm paperclipai onboard --yes --bind lan
pnpm paperclipai run --bind tailnet
```

O comando `configure --section server` segue o mesmo comportamento interativo.

## 6. Contrato UX para Doctor

O "doctor" padrão permanece sem flags:

```sh
pnpm paperclipai doctor
```

O "doctor" lê as configurações de modo/exposição e aplica verificações baseadas no modo. As flags opcionais são secundárias.

## 7. Integração Board/Usuário

A identidade do Board deve ser representada por um principal de usuário real para que os recursos baseados em usuários funcionem de forma consistente.

Pontos de integração necessários:

- linha de usuário real em `authUsers` para a identidade do Board
- entrada `instance_user_roles` para a autoridade administrativa do Board
- integração com `company_memberships` para atribuição de tarefas e acesso no nível do usuário

Isso é necessário porque os caminhos de validação de atribuição de usuários validam o membro ativo para `assigneeUserId`.

## 8. Fluxo Claim de `local_trusted` -> `authenticated`

Quando o modo `authenticated` está sendo executado, se o único administrador da instância for `local-board`, o Paperclip emite um aviso de inicialização com uma URL de reivindicação de alta entropia única.

- Formato de URL: `/board-claim/<token>?code=<code>`
- Uso pretendido: reivindicar a propriedade do board por um humano autenticado
- Ação de reivindicação:
  - promove o usuário atualmente autenticado para `instance_admin`
  - diminui o papel de administrador local do Board
  - garante que o usuário reivindicante tenha uma associação ativa em todas as empresas

Isso evita o bloqueio quando um usuário migra do uso local "trusted" com longa duração para o modo `authenticated`.

## 9. Primeiro Setup Administrativo Para Instalações Authenticated Novas

Instalações autenticadas novas começam em `bootstrap_pending` até que o primeiro
`instance_admin` exista.

Para `authenticated/private`, o Paperclip suporta um caminho de configuração baseado no navegador:

1. abra a URL do Paperclip da rede privada ou da interface do aplicativo
2. faça login ou crie uma conta Paperclip
3. escolha "Claim this instance" na tela de configuração

Isso promove o usuário de sessão atualmente autenticado para o primeiro administrador da instância e, em seguida, passa para a configuração normal. O endpoint está disponível apenas para atores de sessão de navegador reais em `authenticated/private`; solicita não autenticadas, chaves de agente, chaves de API do Board e administradores locais implícitos são rejeitadas.

O fallback CLI permanece suportado em todos os estados de configuração autenticados:

```sh
pnpm paperclipai auth bootstrap-ceo
```

Este comando imprime uma URL de convite de administrador inicial única. A aceitação da URL de convite e o "bootstrap invite" compartilham a mesma transação de administrador, portanto, qualquer um dos caminhos que vencer primeiro torna os sucessivos conflitos.

Para `authenticated/public`, o rastreamento baseado no navegador do primeiro administrador é intencionalmente desabilitado. Os deployments públicos devem usar o caminho de convite bootstrap de alta entropia, a menos que um design futuro de deployment público altere explicitamente essa política.

## 10. Nome e Política de Compatibilidade

- nomes canônicos são `local_trusted` e `authenticated` com `private/public`
- nenhuma camada de alias de compatibilidade de longo prazo para variantes de nomenclatura desativadas

## 11. Relação com Outros Documentos

- plano de implementação: `doc/plans/deployment-auth-mode-consolidation.md`
- Contrato V1: `doc/SPEC-implementation.md`
- fluxos de trabalho do operador: `doc/DEVELOPING.md` e `doc/CLI.md`
- mapa de estado de convite: `doc/spec/invite-flow.md`

