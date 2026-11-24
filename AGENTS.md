# Instruções para agentes — Life OS

## Projeto

Life OS é um aplicativo pessoal de estilo de vida para Android e iOS. O produto liga áreas da vida, objetivos, projetos, tarefas, hábitos, rotina e revisões. Leia [life-os.md](life-os.md) para requisitos de produto e [arquitetura.md](arquitetura.md) para decisões técnicas quando a tarefa tocar esses temas.

## Decisões atuais

- Cliente mobile: Flutter e Dart; backend: Supabase/PostgreSQL.
- O repositório contém documentos de produto e arquitetura. Não presuma que app, banco ou pipeline já foram implementados.
- Trate `arquitetura.md` como proposta vigente, sujeita a revisão baseada em documentação atual e evidência do projeto.
- PostgreSQL é a fonte compartilhada oficial. O suporte offline é limitado aos fluxos explicitamente definidos na arquitetura.
- Finanças, notas e IA contextual estão fora do primeiro MVP, salvo pedido explícito do usuário.

## Como trabalhar

- Antes de alterar código, examine o estado real do repositório e os arquivos aplicáveis. Não invente comandos, telas, tabelas, dependências ou infraestrutura existente.
- Faça mudanças pequenas e coerentes com os módulos de domínio. Evite adicionar camadas ou dependências sem necessidade concreta.
- Para Supabase, autenticação, RLS, SQL, migrações ou SDKs Supabase, consulte a documentação oficial atual antes de implementar; nunca exponha chaves administrativas no app.
- Para Flutter e plugins nativos, confira compatibilidade com as versões travadas no projeto antes de propor instalação ou API.
- Proteja dados pessoais. Nunca coloque conteúdo privado em logs, exemplos, fixtures ou telemetria sem anonimização.
- Regras de acesso e invariantes multiusuário devem ser aplicadas no servidor; validação da interface é apenas conveniência.
- Para alterações de produto, explique estados vazios, erro, carregamento, acessibilidade e comportamento sem conexão que sejam relevantes ao fluxo.
- Use agentes auxiliares apenas quando o usuário pedir ou quando a configuração da sessão autorizar. Delegue tarefas independentes, dê escopo e resultado esperado, e revise todo resultado antes de integrá-lo.
- Não crie skills, agentes persistentes, automações, credenciais, serviços externos ou infraestrutura sem pedido explícito. Prefira instruções deste arquivo para convenções específicas do projeto.
- Não afirme que testes, builds, migrações ou verificações passaram sem executá-los. Informe limitações de ambiente e o que ficou sem validação.

## Validação

- Quando o usuário pedir verificação, execute os checks existentes mais próximos da alteração e reporte os resultados observados.
- Para mudanças de banco, confira migração em banco local/staging, políticas RLS e isolamento entre pelo menos duas identidades antes de recomendar produção.
- Para fluxos mobile, considere Android e iOS, estados de rede, ciclo de vida do app e acessibilidade.
