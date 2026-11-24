# Life OS — Design do MVP mobile e primeira fatia

**Data:** 24/11/2026
**Status:** primeira fatia técnica aprovada; o escopo amplo do produto continua sujeito a validação.
**Fontes:** [PRD](../../../life-os.md), [arquitetura](../../../arquitetura.md), [roadmap](../../../ROADMAP.md), [descoberta](../../../DESCOBERTA.md).

## Intenção

Entregar um aplicativo Android/iOS em Flutter para planejamento pessoal que ligue a direção de vida à execução cotidiana. O usuário deve conseguir abrir a tela Hoje, ver até três prioridades, capturar uma tarefa rapidamente e concluir uma ação sem preencher todo o sistema.

A primeira fatia técnica valida o caminho mínimo de ponta a ponta: iniciar o app Flutter, autenticar, criar uma tarefa, persistir no Supabase/PostgreSQL e recuperar a mesma tarefa após encerrar e reabrir o app.

## Usuário e resultado

Público inicial provisório: pessoa que concilia trabalho ou estudo, responsabilidades pessoais e projetos próprios. É hipótese baseada no PRD, não persona validada. O foco é deixar o planejamento do começo do dia rápido e claro.

Direção escolhida: minimalista, masculina, sóbria e prática, com fundo claro, tipografia forte, separadores simples e violeta como acento. O violeta será usado em poucos pontos da interface. Não usar verde como cor principal, visual de spa, botânica decorativa ou mensagens de autoajuda.

## Escopo do MVP

### Incluído

- App Flutter/Dart para Android e iOS.
- Login por e-mail/senha, recuperação de acesso e sessão persistente.
- Onboarding pulável; não bloquear o uso de tarefas até configurar metas.
- Áreas da vida, avaliações históricas e roda da vida.
- Objetivos e metas, projetos e tarefas.
- Caixa de entrada; captura com título obrigatório e demais campos opcionais.
- Tela Hoje com três prioridades, tarefas, agenda do dia e ação principal.
- Planejamento semanal e revisão semanal.
- Hábitos com programação, pausa e histórico.
- Persistência remota no Supabase e RLS por usuário.
- Após validar online: cache e operações offline limitadas para captura/conclusão de tarefas e registro de hábito.
- Estados de carregamento, erro, vazio, sincronização, acessibilidade e permissões negadas.

### Adiado

Finanças, editor de notas, recorrências avançadas, calendário externo, widget e IA contextual. Check-in de humor/energia é opcional e fica fora da primeira fatia; só entra no MVP após decidir finalidade, privacidade, retenção e linguagem.

## Experiência e fluxo

1. Usuário instala e abre o app; pode entrar ou criar conta.
2. Sessão continua após fechar e abrir o app; logout limpa sessão e dados locais da conta conforme regra de pendências.
3. Tela Hoje apresenta data local, três prioridades ou estado vazio, ação “Adicionar tarefa” e resumo curto.
4. Criar tarefa pede somente título. Após salvar, ela aparece imediatamente na lista e sincroniza com o servidor.
5. Ao reabrir o app com internet, a tarefa continua presente. Erro de rede informa que não sincronizou e oferece tentar novamente.
6. Onboarding de áreas/metas pode ser feito depois.

## Regras propostas para fechar o MVP

| Tema | Padrão proposto |
|---|---|
| Autenticação | E-mail e senha; recuperação por e-mail. Sem login anônimo no primeiro lançamento |
| Rede | Login e primeira sincronização exigem rede. Cache local mostra dados já carregados |
| Offline inicial | Depois da fatia online: capturar/concluir tarefa e registrar hábito; fila local visível e idempotente |
| Prioridades | Até três por dia; quarto item exige substituição explícita |
| Lembretes | Desligados por padrão; lembrete local opcional para revisão semanal. Pedir permissão ao ativar |
| Tom | Direto, adulto e prático; sem frases terapêuticas ou motivacionais genéricas |
| Cor | Violeta de acento sobre neutros claros; remover verde primário |
| Horário | Fuso IANA configurável; data local separada de instante UTC |
| Região Supabase | Proposta inicial: região São Paulo se disponível no projeto/plano escolhido; confirmar no console e medir latência antes de produção |
| Contas de lojas | Proprietário cria/gerencia Apple Developer e Google Play Console; não armazenar credenciais no repositório |
| Orçamento | Definir limite mensal antes de beta público; alertas de uso e custos antes de produção |

Esses padrões são recomendações de implementação, exceto a direção violeta minimalista, explicitamente escolhida pelo usuário. Mudança de padrão que altere dados, acesso ou experiência principal volta para revisão.

## Primeira fatia funcional: critérios de aceitação

- Build de desenvolvimento executa em pelo menos um Android físico/emulador e um iOS Simulator ou aparelho compatível.
- Usuário consegue criar conta, sair, entrar e recuperar acesso, com sessão recuperada no próximo início.
- Usuário autenticado cria tarefa com título e recebe confirmação após persistência remota.
- Tarefa aparece depois de fechar/abrir o aplicativo e autenticar novamente.
- Duas contas diferentes não conseguem ler, atualizar ou associar a tarefa uma da outra.
- Sem internet, falha de criação não é apresentada como sincronizada; UI mostra erro/pendência com ação de retry.
- Tentativa repetida após timeout não cria duplicatas.
- Nenhuma chave privilegiada Supabase está no cliente ou no repositório.
- Validação funcional é executada em builds Flutter com projeto Supabase de staging, não só no protótipo visual.

## Arquitetura da fatia

Flutter/Dart apresenta autenticação, Hoje e formulário de tarefa. Um caso de uso `CreateTask` valida título e chama repositório. O adaptador Supabase grava a linha sob RLS. O PostgreSQL possui `tasks`, `user_id`, timestamps e constraints mínimas. Testes cobrem validação de domínio, repositório, RLS entre duas identidades e retomada da sessão.

SQLite e fila offline não entram nesta primeira fatia, pois a arquitetura define que se valide persistência online antes de sincronização offline. A tela deve deixar claro que tarefa foi salva no servidor. Nenhum comando de publicação ou provisionamento de projeto hospedado faz parte do primeiro build local.

## Abordagens consideradas

| Abordagem | Troca | Decisão |
|---|---|---|
| Flutter + Supabase direto com RLS e RPC para invariantes | Menos infraestrutura, autenticação e PostgreSQL gerenciados | Recomendada e compatível com a escolha já feita |
| Flutter + API própria + PostgreSQL | Controle detalhado de servidor | Mais operação e superfície de falhas sem necessidade atual |
| Flutter online-first com SQLite depois | Valida persistência e sessão antes de sync | Recomendada para a primeira fatia; offline entra por etapas |
| Offline-first desde o primeiro dia | Captura sempre disponível | Amplia conflitos, migrações e teste antes de provar o fluxo básico |

## Dependências e riscos

- Flutter/Dart, Android SDK 36, JDK e Supabase CLI estão instalados; Docker Desktop está ativo e a stack local do Supabase está iniciada.
- A primeira fatia usa Supabase local; projeto hospedado e credenciais de staging não são necessários para começar.
- O AVD Android API 36 foi criado e inicializado com sucesso; fica desligado até a execução do app.
- Compilação e validação iOS precisam ocorrer em macOS com Xcode; esta máquina Windows cobre Android.
- Região, custos e disponibilidade de recuperação do Supabase precisam ser confirmados no plano escolhido.
- Plugins de sessão e login dependem de compatibilidade com versões travadas de Flutter/Dart.
- Excluir conta, exportar dados e validar requisitos das lojas precisa estar resolvido antes de publicação pública.

## Fora de escopo

- Publicar nas lojas, criar contas externas ou provisionar infraestrutura.
- Integrar calendário, bancos, Apple Health ou Google Fit.
- Assistente que muda tarefas ou agenda sozinho.
- Prometer funcionamento offline completo ou confiabilidade absoluta.
- Registrar conteúdo pessoal em logs.

## O que ainda falta para execução

1. Iniciar o AVD `LifeOS_API_36` ou conectar um Android com depuração USB ao validar a interface no aparelho.
2. Validar o build iOS em um Mac com Xcode antes de considerar suporte iOS verificado.
3. Criar projeto hospedado, credenciais e limites de custo apenas quando chegar a hora de staging/beta; não são pré-requisitos para a primeira fatia local.

O plano aprovado define a primeira entrega como um app Flutter executável com login por e-mail/senha, sessão persistente e criação/leitura de tarefas no PostgreSQL local, protegido por RLS. A validação começa online; sincronização offline e recursos amplos do Life OS ficam para etapas posteriores. A próxima atividade de produto é implementar a Task 1 do plano, sem esperar pelo ambiente iOS.
