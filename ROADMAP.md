# Life OS — Roadmap do projeto

**Data:** 24/11/2026
**Status:** base mobile implementada; núcleo de direção em andamento no Flutter e no Supabase local.
**Base:** [PRD](./life-os.md), [arquitetura mobile](./arquitetura.md) e [instruções para agentes](./AGENTS.md).

## Estado atual

- Ambiente local preparado: Flutter/Dart, Android SDK, emulador Android, Docker Desktop e Supabase CLI.
- App Flutter criado em `apps/mobile`; cliente Supabase usa somente URL e chave publicável de desenvolvimento, fora do Git.
- Migração inicial e isolamento de `tasks` por RLS aplicados no Supabase local; suíte pgTAP passou em 12 verificações.
- Login, cadastro, recuperação de senha, sessão em armazenamento seguro e fluxo Hoje com criação/leitura de tarefas implementados.
- `flutter analyze`, 10 testes Flutter, migrações e 12 verificações pgTAP passaram; build e jornada Android foram validados no emulador.
- Persistência após reabrir o app e isolamento entre duas contas foram verificados no Android local e no banco.
- Fase 2 iniciada: oito áreas padrão, edição/ordenação/arquivamento, avaliações por data, notas de atenção, média e histórico com roda acessível.
- As novas migrações foram aplicadas no Supabase local; advisors não apontam issues. `flutter analyze` está limpo e o APK debug foi gerado.
- O fluxo das novas tabelas ainda não passou por pgTAP nem por jornada manual no emulador; suas políticas RLS precisam dessa validação antes de produção.
- iOS ainda exige macOS/Xcode. Não existe ambiente hospedado, assinatura de release, CI ou fila offline.
- Próximo: onboarding retomável, visão de vida e metas anuais/trimestrais com critérios de sucesso e progresso.

## Visão do roadmap

Entregar primeiro um ciclo de uso confiável: a pessoa entende o momento atual, escolhe uma direção, organiza ações, executa o dia e aprende na revisão semanal. Cada fase termina com algo utilizável e verificável. Prazos são estimados em semanas de trabalho de uma pessoa e serão recalibrados quando a primeira versão executável revelar esforço real.

## Princípios de sequência

- Validar a experiência e a persistência numa jornada pequena antes de construir todos os módulos.
- Estabelecer autenticação, isolamento, migrações e recuperação antes de guardar dados pessoais em produção.
- Priorizar a experiência diária e o ciclo semanal completo; módulos futuros só avançam com evidência de uso.
- Manter tarefas e hábitos essenciais utilizáveis com rede instável, conforme os limites do PRD e da arquitetura.
- Não adicionar dependências, automações ou funcionalidades de IA sem benefício claro para a pessoa usuária.

## Fases

| Fase | Estimativa inicial | Resultado esperado |
|---|---:|---|
| 0. Descoberta e decisões | 1–2 semanas | Fluxos prioritários e decisões de produto/infraestrutura validados |
| 1. Fundação técnica | 2–3 semanas | App Flutter executável em Android/iOS, Supabase local/staging e pipeline básico |
| 2. Núcleo de direção | 2–4 semanas | Áreas da vida, avaliações e objetivos persistidos com segurança |
| 3. Execução diária | 3–5 semanas | Projetos, tarefas, prioridades e tela Hoje |
| 4. Semana e hábitos | 3–5 semanas | Planejamento semanal, hábitos e revisão fecham o ciclo do produto |
| 5. Confiabilidade e beta | 2–4 semanas | Dados exportáveis, exclusão funcional e versão beta observável |
| 6. Lançamento inicial | 1–2 semanas | Publicação gradual para usuários iniciais |
| V2. Expansão | A estimar após beta | Finanças, notas e integrações escolhidas por evidência |
| V3. Assistência contextual | A estimar após V2 | IA opcional para sugestões revisáveis, com permissões limitadas |

Estimativa total até o primeiro lançamento: **14–25 semanas de trabalho de uma pessoa**, excluindo espera de revisão das lojas, pesquisa extensa, atrasos de terceiros e trabalho comercial. A faixa é direcional, não compromisso de calendário.

### Fase 0 — Descoberta e decisões

**Entregas**

- Definir usuário inicial e principal contexto de uso do Life OS.
- Escolher a jornada de primeira sessão e o que pode ser pulado.
- Desenhar e testar protótipos de Hoje, Planejar, Hábitos e Vida.
- Especificar estados vazios, captura rápida, navegação, acessibilidade e tom visual.
- Confirmar país/região de hospedagem, custo do plano Supabase, política de privacidade e exigências de publicação das lojas.
- Rever a arquitetura com versões efetivamente escolhidas de Flutter, Dart e plugins.

**Critério de saída:** pelo menos cinco pessoas do público-alvo conseguem explicar e completar a jornada central no protótipo sem orientação; decisões que afetam custo, privacidade ou sincronização ficam registradas.

### Fase 1 — Fundação técnica

**Entregas**

- Workspace Flutter/Dart com ambientes dev, staging e produção claramente separados.
- Tema inicial, navegação, configuração de sessão e estados de carregamento/erro.
- Supabase local, esquema inicial, migrações versionadas e RLS desde a primeira tabela.
- Identidade por e-mail, recuperação de acesso e isolamento de dados validado entre duas contas.
- Camadas de domínio, aplicação e adaptadores de dados sem sobre-engenharia.
- Registro de erros sem conteúdo pessoal, CI para formatação, análise estática, tipos e testes existentes.
- Decisão verificada sobre armazenamento seguro de sessão e escolha/configuração do SQLite criptografado.

**Critério de saída:** builds de desenvolvimento abrem em Android e iOS; migração pode ser aplicada num banco limpo; operações de uma conta não leem nem alteram dados de outra.

### Fase 2 — Núcleo de direção

**Entregas**

- Onboarding retomável e ignorável.
- Oito áreas iniciais, edição, ordenação e arquivamento.
- Roda da vida com avaliações datadas, notas entre 0 e 10, comentários opcionais e comparação histórica.
- Visão de vida, objetivos anuais e metas trimestrais com critérios de sucesso e progresso.
- Indicador de atenção a áreas e aviso para mais de três metas trimestrais ativas.
- Histórico preservado; média calculada apenas sobre áreas avaliadas.

**Critério de saída:** usuário cria, edita, arquiva e revisita avaliações/metas; o histórico não muda quando inicia uma nova avaliação; dados permanecem isolados.

### Fase 3 — Execução diária

**Entregas**

- Projetos ligados opcionalmente a metas e áreas.
- Caixa de entrada de tarefas com captura mínima por título.
- Datas planejadas e prazos com significados separados; filtros e reagendamento explícito.
- Até três prioridades diárias com substituição consciente.
- Tela Hoje com prioridades, tarefas pendentes/atrasadas, próximos blocos e resumo das metas.
- Operações atômicas de prioridade; fila local para capturar tarefa e concluir tarefa.
- Estado claro de sincronização pendente, conflito e falha.

**Critério de saída:** uma tarefa criada rapidamente pode ser organizada depois; concorrência e repetição de pedidos não criam prioridades duplicadas; operação offline suportada sobrevive ao encerramento do app.

### Fase 4 — Semana, hábitos e experiência de estilo de vida

**Entregas**

- Planejamento semanal com três focos e distribuição de ações por dia.
- Calendário diário/semanal com blocos e alertas de sobreposição não bloqueantes.
- Hábitos com frequência, pausa, histórico de programação e registro único por dia.
- Revisão semanal com rascunho, retomada e histórico.
- Humor/energia como check-in opcional, privado e não clínico.
- Rituais simples de início/fim do dia, sugestões de descanso e feedback visual discreto.
- Preferências de tema, lembretes e movimento reduzido; tudo opcional.
- Captura rápida acessível por ação global e atalho do sistema, se viável sem sacrificar compatibilidade.

**Critério de saída:** o usuário consegue planejar, executar e revisar uma semana completa; pular hábitos/check-ins não gera culpa nem métricas punitivas; permissões de notificação são solicitadas somente quando necessárias.

### Fase 5 — Confiabilidade, privacidade e beta

**Entregas**

- Exportação dos dados do usuário e solicitação de exclusão retomável.
- Recuperação de sessão, logout com pendências, troca de conta e conflitos testados.
- Restore de banco e arquivos exercitado em ambiente isolado; retenção e limites de recuperação documentados.
- Testes de domínio, banco/RLS, migrações, concorrência e jornada mobile prioritária.
- Testes em aparelhos físicos Android e iOS: rede ruim, pouco espaço, app encerrado, permissões negadas e leitores de tela.
- Instrumentação de crashes, latência, filas e falhas de autenticação sem registrar textos privados.
- Beta fechado com feedback voluntário e canal simples para reportar problemas.
- Medição de tempo de abertura e resposta local em aparelhos de referência; metas da arquitetura revisadas com dados reais.

**Critério de saída:** falhas não perdem operações locais pendentes; nenhuma vulnerabilidade crítica/alta conhecida fica aberta; suporte consegue diagnosticar problemas sem pedir conteúdo privado; restauração atende metas de recuperação aprovadas.

### Fase 6 — Lançamento inicial

**Entregas**

- Textos de loja, política de privacidade, suporte e processo de exclusão publicados.
- Builds assinados e verificados em canais internos antes da submissão pública.
- Rollout gradual e plano de interromper distribuição se crashes ou falhas de sincronização subirem.
- Alertas e runbooks acessíveis a quem mantém o app.
- Revisão de feedback e métricas após 1, 2 e 4 semanas.

**Critério de saída:** publicar somente depois de confirmar os requisitos atuais das lojas e que os indicadores beta estão dentro das metas aprovadas; reverter rollout se sinais de integridade de dados ou crash excederem os limites definidos.

### V2 — Expansão guiada por uso

Possíveis entregas: finanças pessoais manuais, notas associadas a áreas/projetos, recorrência com exceções, calendário externo e notificações mais completas. Priorizar apenas o que usuários beta pedirem e que não prejudique o uso diário.

**Porta de decisão:** escolher no máximo dois módulos para investigação de cada vez; revisar custo de suporte, privacidade, retenção e impacto na manutenção antes de comprometer implementação.

### V3 — Assistente contextual

Possível assistente que resume a semana, ajuda a decompor metas e sugere ajustes. O usuário revisa e confirma qualquer mudança. A IA não altera automaticamente prioridades, agenda, finanças ou hábitos.

**Pré-condições:** métricas de utilidade do ciclo principal, catálogo explícito de dados acessíveis, consentimento granular, política de retenção, avaliação de qualidade, proteção contra prompt injection em notas e plano de desligamento do recurso.

## Sequência recomendada de validação

1. Antes de implementar o produto completo, provar uma fatia vertical: login → criar tarefa → persistir em Supabase → reabrir app → sincronizar após queda de rede.
2. Validar o modelo de dados e RLS com duas contas antes de armazenar informação real.
3. Testar os fluxos principais com protótipo antes de ampliar a biblioteca de componentes.
4. Acrescentar sincronização offline somente depois que gravações online e tratamento de conflito estiverem claros.
5. Fazer beta antes do lançamento para medir confiabilidade e utilidade, não apenas volume de tarefas concluídas.

## Indicadores para decisões de produto

- Ativação: criou uma meta e uma tarefa durante a primeira semana.
- Valor inicial: concluiu uma revisão semanal na primeira semana completa.
- Uso recorrente: definiu prioridades em semanas consecutivas.
- Retenção: voltou na quarta semana após ativação.
- Saúde: crashes por sessão, erros de sincronização e idade da pendência mais antiga.
- Bem-estar: avaliação voluntária de clareza e organização, sem incentivar mais tempo no app.

Sempre interpretar os indicadores com entrevistas e feedback. Não otimizar streaks, notificações ou número de tarefas se isso aumentar a carga mental ou reduzir descanso.

## Decisões em aberto para a Fase 0

- Público inicial e problema cotidiano mais importante.
- Direção visual de “lifestyle” e nível de personalização.
- Necessidade de login obrigatório no primeiro protótipo ou modo local primeiro.
- Orçamento mensal e região de hospedagem.
- Estratégia de distribuição beta e aparelhos mínimos suportados.
- Qual experiência extra tem prioridade: check-in de bem-estar, ritual diário, tema visual ou widget.

## Registro de mudanças do roadmap

Este documento é uma linha de base inicial. Atualizar estimativas e critérios depois da fatia vertical, do primeiro teste de usabilidade e do beta; manter o PRD como referência de escopo do produto e a arquitetura como referência técnica.
