# Life OS mobile

Flutter mobile app for Android and iOS. This scaffold currently starts at the sign-in route; Supabase authentication and task persistence are implemented in the following plan tasks.

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

The app can still open without backend configuration while the auth flow is
under development. Supplying only one of the two values fails at startup with a
configuration error instead of silently connecting to the wrong environment.
