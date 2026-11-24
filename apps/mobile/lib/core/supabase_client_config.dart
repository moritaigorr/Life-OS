import 'package:supabase_flutter/supabase_flutter.dart';

/// Bootstraps the public Supabase client used by the mobile app.
///
/// Only a project URL and publishable key belong in this client. Secret keys
/// and service-role credentials must remain on trusted servers.
abstract final class SupabaseClientConfig {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => _url.isNotEmpty && _publishableKey.isNotEmpty;

  static SupabaseClient? get client =>
      isConfigured ? Supabase.instance.client : null;

  static Future<SupabaseClient?> initialize() async {
    if (_url.isEmpty && _publishableKey.isEmpty) return null;
    if (_url.isEmpty || _publishableKey.isEmpty) {
      throw StateError(
        'Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY together.',
      );
    }

    final uri = Uri.tryParse(_url);
    if (uri == null ||
        !uri.hasAuthority ||
        !const {'http', 'https'}.contains(uri.scheme)) {
      throw StateError('SUPABASE_URL must be a valid http(s) URL.');
    }

    await Supabase.initialize(url: _url, publishableKey: _publishableKey);
    return Supabase.instance.client;
  }
}
