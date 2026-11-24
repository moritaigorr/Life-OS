# Life OS mobile

Flutter mobile app for Android and iOS. The first usable slice includes email authentication, secure session persistence, password recovery, and the Today task list backed by local Supabase.

## Development environment

- Flutter 3.50.1 stable
- Dart 3.14.0
- Android SDK 36.0.0 and Build Tools 36.0.0
- Eclipse Temurin JDK 25.0.4.1
- Android emulator `LifeOS_API_36` (Pixel 6 profile, Google APIs x86_64); boot tested successfully
- No physical Android device was attached during setup
- iOS project files are generated, but building/running iOS requires macOS and Xcode

Flutter reports Visual Studio as missing for Windows desktop builds. The project targets mobile, so that warning does not block Android work.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter emulators --launch LifeOS_API_36
flutter run
```

## Local Supabase configuration

Create `env/local.json` from `env/example.json`. Supply only a Supabase project
URL and its publishable key; never use a secret or service-role key in Flutter.
The local Android emulator reaches the host machine at `http://10.0.2.2:54321`.
For a simulator or desktop client, use the host's loopback address instead.

Run from `apps/mobile` with:

```powershell
flutter run --dart-define-from-file=env/local.json
```

The app can open without backend configuration for UI development. Supplying
only one of the two values fails at startup with a configuration error instead
of silently connecting to the wrong environment.

## Local authentication

From the repository root, start the local Supabase stack and apply migrations:

```powershell
supabase start
supabase migration up
supabase test db
```

Local email confirmation is disabled for development. Sign up with a test email
and a password of at least 8 characters, then sign in. Password recovery uses
the `lifeos://auth/recover` callback registered in Android and iOS. Supabase
Auth persists session tokens and short-lived PKCE verifiers in Android secure
storage or the iOS Keychain; signing out immediately returns to the sign-in
screen. Do not use a real personal password for local tests.

The current task flow is online-first: failed requests remain visible and can
be retried with the same operation ID. No task is presented as saved until the
server confirms it. Offline writes are not queued in this slice.
