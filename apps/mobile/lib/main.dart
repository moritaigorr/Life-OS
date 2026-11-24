import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/supabase_client_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseClientConfig.initialize();
  runApp(const LifeOsApp());
}
