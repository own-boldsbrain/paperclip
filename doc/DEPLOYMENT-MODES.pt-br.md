# Modos de Implantação

Status: Modelo padrão de implantação e autenticação
Data: 2026-02-23

## 1. Propósito

O Paperclip suporta dois modos de tempo de execução:

1. `local_trusted`
2. `authenticated`

O modo `authenticated` suporta duas políticas de exposição:

1. `private`
2. `public`

Isso mantém uma pilha de autenticação unificada, ao mesmo tempo em que separa os valores padrão privados da rede de requisitos de segurança para interface com a internet.

Agora, o Paperclip trata **bind** como uma preocupação separada da autenticação:

- modelo de autenticação: `local_trusted` vs `authenticated`, além de `private/public`
- modelo de acessibilidade: `server.bind = loopback | lan | tailnet | custom`

## 2. Modelo Padrão

| Modo de Tempo de Execução | Exposição | Autenticação Humana | Uso Primário |
|---|---|---|---|
| `local_trusted` | n/a | Sem necessidade de login | Fluxo de máquina local para um único operador |
| `authenticated` | `private` | Necessita login | Acesso à rede privada (por exemplo, Tailscale/VPN/LAN) |
| `authenticated` | `public` | Necessita login | Implantação orientada à internet/nuvem |

## 3. Modelo de Acessibilidade

| Bind | Significado | Uso Típico |
|---|---|---|
| `loopback` | Escuta apenas na localhost | Uso local padrão, implantações de reverse proxy |
| `lan` | Escuta em todas as interfaces (`0.0.0.0`) | Acesso à LAN/VPN/rede privada |
| `tailnet` | Escuta em um endereço IP Tailscale detectado | Acesso apenas a Tailscale |
| `custom` | Escuta em um host/IP específico | Configurações específicas da interface avançadas |

## 4. Política de Segurança

## `local_trusted`

- Ligação de host apenas com loopback
- Sem fluxo de login humano
- Otimizado para o mais rápido tempo de inicialização local

## `authenticated + private`

- Necessita login
- Tratamento URL de baixo atrito (`auto` modo de URL base)
- Política de confiança de host privado necessária
- O bind pode ser `loopback`, `lan`, `tailnet` ou `custom`

## `authenticated + public`

- Necessita login
- URL público explícita necessária
- Verificações e falhas mais rigorosas no doctor
- Bind recomendado é `loopback` atrás de um reverse proxy; o direct `lan/custom` é avançado

## 5. Contrato UX de Onboarding

O onboarding padrão permanece interativo e sem flags:

```sh
pnpm paperclipai onboard
```

Comportamento do prompt do servidor:

1. `server.bind=loopback` assume automaticamente o valor padrão para o modo `local_trusted/private`
2. A configuração avançada do servidor pergunta primeiro sobre a acessibilidade:

- `Trusted local` ? 'bind=loopback', `local_trusted/private`
- `Private network` ? 'bind=lan', `authenticated/private`
- `Tailnet` ? 'bind=tailnet', `authenticated/private`
- `Custom` ? modo manual/exposição/entrada de host

1. A entrada de host bruta é necessária apenas para o caminho `Custom`
2. A URL pública explícita é necessária apenas para `authenticated + public`

Exemplos:

```sh
pnpm paperclipai onboard --yes
pnpm paperclipai onboard --yes --bind lan
pnpm paperclipai run --bind tailnet
```

O comando `configure --section server` segue o mesmo comportamento interativo.

## 6. Contrato UX de Doctor

O doctor padrão permanece sem flags:

```sh
pnpm paperclipai doctor
```

O doctor lê as configurações do modo/exposição e aplica verificações conscientes do modo. As opções de supressão secundárias são opcionais.

## 7. Integração Board/Usuário

A identidade do board deve ser representada por um usuário real no banco de dados para que os recursos baseados em usuários funcionem consistentemente.

Pontos de integração necessários:

- linha de usuário real em `authUsers` para a identidade do board
- entrada `instance_user_roles` para a autoridade administrativa do board
- integração `company_memberships` para a atribuição de tarefas e acesso de nível de usuário

Isso é necessário porque os caminhos de atribuição de usuários validam a associação ativa para `assigneeUserId`.

## 8. Fluxo de reivindicação Local Trusted -> Autenticado

Quando o modo `authenticated` é executado, se o único administrador da instância for `local-board`, o Paperclip emite um aviso de inicialização com uma URL de reivindicação de alta entropia.

- Formato de URL: `/board-claim/<token>?code=<code>`
- Uso pretendido: reivindicar a propriedade do board para usuários humanos autenticados
- Ação de reivindicação:
  - Promove o usuário atualmente logado como `instance_admin`
  - Demote o papel de administrador do `local-board`
  - Garante que o membro proprietário ativo esteja presente para o usuário reivindicando em todas as empresas existentes

Isso evita bloqueios quando um usuário migra do uso local de confiança com tempo de execução longo para o modo autenticado.

## 9. Primeira Configuração de Admin Para Instalações Autenticadas Novas

Instalações autenticadas novas começam no estado `bootstrap_pending` até que o primeiro
`instance_admin` exista.

Para `authenticated/private`, o Paperclip suporta um caminho de configuração baseado em navegador:

1. abra a URL do Paperclip da rede privada ou da interface do aplicativo
2. faça login ou crie uma conta Paperclip
3. escolha "Claim this instance" na tela de configuração

Isso promove o usuário de sessão atualmente logado como o primeiro administrador de instância e então passa para a etapa normal de onboarding. O endpoint está disponível apenas para atores no navegador reais em `authenticated/private`; solicita não autenticadas, chaves de agente, chaves de API do board e administradores implícitos locais são rejeitadas.

O fallback CLI permanece suportado em todos os estados de configuração autenticados:

```sh
pnpm paperclipai auth bootstrap-ceo
```

Este comando imprime uma URL de convite de admin inicial. A aceitação da URL de convidado e o boot do convite compartilham a mesma transação de admin inicial, então qualquer um dos caminhos que ganha primeiro, torna as tentativas posteriores em conflito.

Para `authenticated/public`, o uso do claim de admin inicial baseado no navegador é intencionalmente desabilitado. As implantações públicas devem usar o caminho de convite de alta entropia a menos que um projeto de implantação pública futuro altere explicitamente esta política.

## 10. Nome e Política de Compatibilidade

- O nome canônico é `local_trusted` e `authenticated` com `private/public`
- Sem camada de alias de compatibilidade de longo prazo para variantes de nomenclatura desativadas

## 11. Relação com Outros Documentos

- Plano de implementação: `doc/plans/deployment-auth-mode-consolidation.md`
- Contrato V1: `doc/SPEC-implementation.md`
- Fluxo de trabalho do operador: `doc/DEVELOPING.md` e `doc/CLI.md`
- Mapa de estado de convite/entrada: `doc/spec/invite-flow.md`
