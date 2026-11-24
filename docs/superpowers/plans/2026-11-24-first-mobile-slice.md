# Life OS First Mobile Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Flutter mobile slice where a user authenticates, creates a task in Supabase, and sees that task again after reopening the app.

**Architecture:** Flutter/Dart app organized around a small task domain and repository boundary. Supabase Auth manages identity; PostgreSQL stores tasks protected by RLS. The first slice is online-first; SQLite/offline queue are deferred until remote persistence and session recovery work.

**Tech Stack:** Flutter/Dart, `supabase_flutter`, `go_router`, Riverpod, PostgreSQL/Supabase Auth, Flutter test tooling, pgTAP or SQL assertions for database policies.

**Spec:** `docs/superpowers/specs/2026-11-24-life-os-mvp-design.md`

## Global Constraints

- “App Flutter/Dart para Android e iOS.”
- “Login por e-mail/senha, recuperação de acesso e sessão persistente.”
- “Onboarding pulável; não bloquear o uso de tarefas até configurar metas.”
- “Caixa de entrada; captura com título obrigatório e demais campos opcionais.”
- “Persistência remota no Supabase e RLS por usuário.”
- “Nenhuma chave privilegiada Supabase está no cliente ou no repositório.”
- “SQLite e fila offline não entram nesta primeira fatia, pois a arquitetura define que se valide persistência online antes de sincronização offline.”
- “Direção escolhida: minimalista, masculina, sóbria e prática, com fundo claro, tipografia forte, separadores simples e violeta como acento.”
- Use only documented, version-compatible Flutter/Supabase packages; commit lockfiles and migrations.
- Never log task content, passwords, session tokens, or secret keys.

## Review Focus

- Expired or missing session during app restart: route to sign-in without showing another user's cached data. Test in Task 3.
- Cross-account task reads/writes and forged `user_id`: deny at PostgreSQL RLS, not only in Flutter. Test in Task 2.
- Network loss or timeout after server commit: show truthful state and prevent duplicate task creation on retry. Test in Task 4.
- Empty/whitespace-only title and overly long title: reject clearly before sending the request and enforce a database length ceiling. Test in Task 4.
- Deep link or password recovery with malformed/unknown callback: fail safely and do not route into an authenticated page. Test in Task 3.

---

## File Map

Initial proposed Flutter layout (adjust only to match the generated Flutter template conventions):

```text
apps/mobile/
  pubspec.yaml                 # Flutter dependencies and app metadata
  lib/main.dart                # bootstrap and dependency composition
  lib/app.dart                 # Material 3 theme, router and session refresh
  lib/core/supabase_client.dart # configured public client, no service key
  lib/features/auth/            # sign-in, sign-up, reset password and session state
  lib/features/tasks/           # task model, repository, use case and Hoje UI
  test/features/auth/           # auth and route behavior
  test/features/tasks/          # validation and repository behavior
supabase/
  config.toml                   # local Supabase configuration
  migrations/<generated>.sql    # schema, constraints and RLS
  tests/                         # RLS isolation assertions
```

If this repository remains a document-only repo, add the Flutter workspace under `apps/mobile/`; do not move or rewrite the existing PRD, architecture, discovery, roadmap, or agent instructions.

## Task 1: Prepare and scaffold Flutter workspace

**Files:**
- Create: `apps/mobile/` Flutter project files using the installed stable Flutter SDK.
- Create: `apps/mobile/lib/main.dart`
- Create: `apps/mobile/lib/app.dart`
- Create: `apps/mobile/test/widget_test.dart`
- Create: `.gitignore` additions only if required for generated Flutter files.

**Interfaces:**
- Produces: `LifeOsApp` root widget; app starts without an authenticated session and displays the sign-in route.

- [ ] **Step 1: Confirm toolchain and target platforms**

Run `flutter --version`, `dart --version`, `flutter doctor -v`, and inspect Android/iOS availability. Record SDK versions and device/simulator availability in `apps/mobile/README.md`.

- [ ] **Step 2: Create scaffold and verify the starter failure**

Create the Flutter project in `apps/mobile` without overwriting repository files. Add a widget test asserting the app shows the sign-in screen. Run `flutter test`; expected failure is that the sign-in screen is not implemented yet.

- [ ] **Step 3: Implement minimal app bootstrap**

Add `main()` and `LifeOsApp` with Material 3 theme and a placeholder sign-in route. Keep visual tokens in one theme file; use the selected neutral/violet direction.

- [ ] **Step 4: Verify scaffold**

Run `flutter analyze` and `flutter test`; expected: clean analysis and widget test passes.

## Task 2: Supabase local setup, tasks schema and row security

**Files:**
- Create: `supabase/config.toml` via Supabase CLI init.
- Create: generated migration for `public.tasks`.
- Create: `supabase/tests/tasks_rls.sql`.
- Modify: `apps/mobile/pubspec.yaml` only for pinned compatible Supabase Flutter dependency.
- Create: `apps/mobile/lib/core/supabase_client.dart`.

**Interfaces:**
- Produces: `tasks` rows with `id uuid`, `user_id uuid`, `title text`, `created_at timestamptz`, `updated_at timestamptz`.
- Client config reads the Supabase URL and publishable/anon key from local build configuration; never accepts a service-role/secret key.

- [ ] **Step 1: Write RLS isolation SQL assertions**

Add tests for unauthenticated denial, owner read/insert/update, another user's read/update denial, forged `user_id` denial, and blank/oversized title constraints.

- [ ] **Step 2: Run assertions and confirm they fail against absent schema/policies**

Run the local database test command documented by the installed Supabase CLI; expected: missing relation/policy failure, not a syntax failure.

- [ ] **Step 3: Add schema and policies**

Create `tasks` with UUID primary key, non-null authenticated `user_id`, trimmed title length 1–200, server timestamps and index `(user_id, created_at desc)`. Enable RLS and add SELECT/INSERT/UPDATE/DELETE policies scoped to `(select auth.uid()) = user_id`; use `WITH CHECK` on writes. Revoke unneeded table/function access and grant only required operations to `authenticated`.

- [ ] **Step 4: Verify schema and security tests**

Apply migrations to a clean local Supabase instance and run the SQL assertions. Expected: owner can access own tasks; anonymous/other identity/forged ownership cases are denied.

- [ ] **Step 5: Add safe client configuration**

Initialize Supabase Flutter using only public URL and publishable/anon key. Load local values from an ignored `.env`/build define; commit only a `.env.example` with placeholders. Confirm no service key appears in app source, assets, or Git diff.

## Task 3: Authentication and route protection

**Files:**
- Create: `apps/mobile/lib/features/auth/auth_repository.dart`
- Create: `apps/mobile/lib/features/auth/auth_controller.dart`
- Create: sign-in, sign-up and password-reset screens under `apps/mobile/lib/features/auth/`.
- Modify: `apps/mobile/lib/app.dart`
- Create: tests under `apps/mobile/test/features/auth/`.

**Interfaces:**
- `AuthRepository.signIn(email, password)`, `signUp(email, password)`, `sendPasswordReset(email)`, `signOut()`, and `authStateChanges`.
- Router sends unauthenticated sessions to auth routes and authenticated sessions to `/today`; recovery deep links are validated before routing.

- [ ] **Step 1: Write auth and redirect tests**

Cover unauthenticated redirect, authenticated access to `/today`, restoration after app restart, sign-out, and malformed recovery callback. No route may render task data before identity resolution.

- [ ] **Step 2: Run auth tests to verify failure**

Run the selected Flutter test target; expected failure is missing repository/controller/router behavior.

- [ ] **Step 3: Implement Supabase auth adapter and auth state**

Keep password/session logic in repository/controller. Persist sessions using the current supported Supabase Flutter flow and platform secure storage integration; do not log credentials or tokens.

- [ ] **Step 4: Implement screens and guarded routing**

Create practical, accessible forms with visible validation/loading/error/success states. Add recovery flow and allow the user to reach task capture without completing life-area onboarding.

- [ ] **Step 5: Verify auth tests and manual local flow**

Run focused tests and complete sign-up → sign-out → sign-in → restart → password reset in a local Supabase environment. Expected: session resumes only for the same account; invalid deep links land on a safe auth route.

## Task 4: Task domain and create/list flow

**Files:**
- Create: `apps/mobile/lib/features/tasks/task.dart`
- Create: `apps/mobile/lib/features/tasks/task_repository.dart`
- Create: `apps/mobile/lib/features/tasks/supabase_task_repository.dart`
- Create: `apps/mobile/lib/features/tasks/create_task.dart`
- Create: `apps/mobile/lib/features/tasks/today_screen.dart`
- Create: task tests under `apps/mobile/test/features/tasks/`.

**Interfaces:**
- `Task(id, userId, title, createdAt, updatedAt)`.
- `TaskRepository.listRecent()` and `create(title, operationId)`.
- `CreateTask.call(title)` trims whitespace; accepts length 1–200; returns persisted `Task` or typed failure.
- `TodayScreen` shows date, task list, add-task control, empty/loading/error states and sync/save status.

- [ ] **Step 1: Write task validation and create behavior tests**

Cover valid title, surrounding whitespace, empty/whitespace-only input, 200-character acceptance, 201-character rejection, list ordering, request timeout and retry with the same `operationId`.

- [ ] **Step 2: Run focused tests and verify expected failures**

Run `flutter test test/features/tasks/`; expected failures identify the missing domain/use case/repository.

- [ ] **Step 3: Implement task model, validation and use case**

Keep validation pure Dart. Do not place Supabase calls in widgets.

- [ ] **Step 4: Implement repository with idempotent create**

Insert with client-generated UUID operation/task ID; on a timeout, retry/query by the same ID and owner before creating another row. Map auth, validation, conflict, offline and unavailable errors to typed results; never tell the user a task synced until the server confirms.

- [ ] **Step 5: Implement Today and capture UI**

Use the selected minimal violet reference, accessible contrast, clear focus order and direct copy. Create with title only; show loading, empty, error/retry, saved and not-synced states. Avoid dashboard feature creep.

- [ ] **Step 6: Verify focused tests and device flow**

Run `flutter analyze`, `flutter test`, then use a staging account to create a task, close/reopen the app and confirm it remains. Simulate network loss before/after submission; retry must not produce duplicates.

## Task 5: End-to-end isolation and release readiness for the slice

**Files:**
- Create: end-to-end or integration test under `apps/mobile/integration_test/`.
- Create/update: `apps/mobile/README.md` with exact local setup, environment variables and verification commands.
- Modify: CI workflow only after local toolchain commands and secret handling are confirmed.

**Interfaces:**
- Verification record lists tool versions, environment, commands, and observed outcomes without user data or secrets.

- [ ] **Step 1: Add two-account integration scenario**

Account A creates a task; Account B cannot list, read, update, or infer its content. Sign out and sign in as B in the same install to check no local leakage.

- [ ] **Step 2: Run end-to-end scenario on Android and iOS target**

Run Flutter integration tests on an Android emulator/device and an iOS simulator/device where available; report a blocked platform explicitly rather than claiming cross-platform validation.

- [ ] **Step 3: Verify repository hygiene**

Inspect tracked files and diff for secrets, generated build artifacts, and accidental changes to planning documents. Confirm `.env` and signing materials remain ignored.

## Plan Self-Review

- Spec coverage: first-slice flow, sign-in/recovery/session, task creation/listing, remote persistence, RLS isolation, retry/no-duplicates, selected visual direction, and Android/iOS validation each have owning tasks. Larger MVP modules and offline queue are explicitly excluded from this slice.
- Review-focus coverage: all five failure classes map to test steps in Tasks 2–5.
- Type consistency: `Task`, `TaskRepository`, `CreateTask`, and auth interfaces are defined before consuming UI/router tasks.
- Environment risk: current shell has no `flutter`, `dart`, or `supabase` commands. Task 1 is blocked until Flutter SDK is installed; Task 2 also requires Supabase CLI and local Docker/Supabase availability. No app code has been generated or verified yet.
- User-provided execution method: “vai fazendo então” authorizes proceeding with the work, but does not select subagent delegation. Follow the repository rule and execute natively unless the user later asks for delegation.
