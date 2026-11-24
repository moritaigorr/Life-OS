# Ambiente de desenvolvimento

Preparado em 24/11/2026 para desenvolver e validar a primeira fatia mobile do Life OS. A configuração é local; não há projeto Supabase de staging ou produção conectado.

## Ferramentas

- Flutter 3.50.1 estável; Dart 3.14.0.
- Android SDK 36.0.0, Build Tools 36.0.0 e Platform Tools.
- Emulador Android `LifeOS_API_36` (Pixel 6, Google APIs 36).
- Eclipse Temurin JDK 25.0.4.1.
- Supabase CLI 3.3.0.
- Docker Desktop 4.85.0, engine 29.6.2 e backend WSL2.

Os caminhos e as variáveis `ANDROID_HOME`, `ANDROID_SDK_ROOT` e `JAVA_HOME` foram gravados no perfil do Windows. Abra um terminal novo para carregar o `PATH` atualizado. A primeira build Android pode instalar automaticamente a versão de NDK exigida pelo projeto.

## Supabase local

O arquivo `supabase/config.toml` configura a stack local. O projeto usa Auth, Postgres e Studio. Analytics locais foram desativados porque o coletor Vector não alcançava a API Docker IPv6 deste ambiente; isso não afeta Auth, REST ou Postgres.

Na raiz do repositório:

```powershell
supabase start
supabase migration up
supabase test db
```

O Studio local fica em `http://127.0.0.1:54323`. `supabase status` exporta também credenciais de serviço: não copie nem publique chaves secretas ou `service_role`. O app só usa URL e chave publicável.

## Executar no Android

Crie `apps/mobile/env/local.json` a partir de `apps/mobile/env/example.json` e preencha com a URL local e a chave publicável local. O arquivo `local.json` é ignorado pelo Git. Para o emulador Android, a URL da máquina host é `http://10.0.2.2:54321`.

```powershell
flutter emulators --launch LifeOS_API_36
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Para analisar e rodar testes:

```powershell
flutter analyze
flutter test
```

O app é online-first nesta primeira fatia. Sem rede, a lista mostra erro e a tarefa não é considerada salva; a fila offline ainda não foi implementada. O retry mantém o mesmo identificador de operação para evitar duplicação após uma resposta ambígua.

## Limites de plataforma

Os arquivos Android e iOS foram gerados e o callback de recuperação de senha usa `lifeos://auth/recover`. Android é validado neste computador pelo emulador. A compilação e execução de iOS exigem macOS e Xcode.

## Escopo preparado

A primeira fatia validada inclui cadastro/login por e-mail e senha, recuperação de acesso, sessão persistente em armazenamento seguro, criação e leitura de tarefas no Postgres, RLS por usuário e retry idempotente. A suíte atual passou em 10 testes Flutter e 12 verificações pgTAP. A jornada Android local verificou cadastro, criação, reabertura com sessão/tarefa preservadas e isolamento usando outra conta. Há um formulário local de ambiente em `apps/mobile/env/example.json`; credenciais de staging e publicação ficam para uma etapa posterior. iOS permanece sem validação por exigir macOS/Xcode. Finanças, notas, IA contextual e sincronização offline continuam fora do MVP inicial.
