# Ambiente de desenvolvimento

Preparação feita em 24/11/2026 para a primeira fatia Android do Life OS.

## Ferramentas instaladas

- Flutter 3.50.1 estável; Dart 3.14.0.
- Android SDK 36.0.0, Build Tools 36.0.0 e Platform Tools.
- Emulador Android com imagem Google APIs 36 (`LifeOS_API_36`, perfil Pixel 6); boot validado e emulador desligado.
- Eclipse Temurin JDK 25.0.4.1.
- Supabase CLI 3.3.0.
- Docker Desktop 4.85.0 com engine 29.6.2 e backend WSL2.

Os caminhos e variáveis `ANDROID_HOME`, `ANDROID_SDK_ROOT` e `JAVA_HOME` foram gravados no perfil do Windows. Abra um terminal novo para receber o `PATH` atualizado.

## Supabase local

O arquivo `supabase/config.toml` foi criado e a stack local está rodando pelo Docker. No diretório raiz do repositório:

```powershell
supabase start
supabase stop
```

URLs locais:

- API: `http://127.0.0.1:54321`
- PostgreSQL: `127.0.0.1:54322`
- Studio: `http://127.0.0.1:54323`
- Mailpit para mensagens de autenticação: `http://127.0.0.1:54324`

Analytics/logs locais foram desligados: o coletor Vector tentava acessar a API de logs do Docker via IPv6 e reiniciava repetidamente neste ambiente Windows/WSL. Isso não afeta Auth, PostgreSQL, REST, Storage ou o fluxo de tarefas; pode ser reavaliado quando houver necessidade de depurar logs no Studio.

As chaves e senhas mostradas pelo `supabase start` são credenciais de desenvolvimento local. Não as publique, não as copie para o app e não as coloque no Git. O cliente Flutter deve usar somente a chave pública local; a chave `service_role` nunca deve ir para o cliente.

## Executar o app

O projeto Flutter ainda não foi criado. Depois da Task 1 do plano:

```powershell
cd apps/mobile
flutter pub get
flutter run
```

Inicie o emulador preparado ou conecte um Android com depuração USB antes de `flutter run`:

```powershell
flutter emulators --launch LifeOS_API_36
```

A compilação iOS exige macOS e Xcode; este Windows não pode produzir ou executar um build iOS local.

## Escopo preparado

A primeira fatia aprovada é online-first: autenticação por e-mail/senha com sessão persistente, criação e leitura de tarefa após reabrir o app e proteção multiusuário com RLS. A base é o Supabase local iniciado neste computador. Cache offline, sincronização, o restante dos módulos do Life OS e credenciais de staging ficam para etapas posteriores.
