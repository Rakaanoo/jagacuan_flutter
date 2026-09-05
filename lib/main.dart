import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/repositories/local_storage_repository.dart';
import 'data/repositories/supabase_nabar_repository.dart';
import 'ui/core/theme.dart';
import 'ui/features/target_list/view_models/target_list_view_model.dart';
import 'ui/features/target_list/views/target_list_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale date formatting
  await initializeDateFormatting('id_ID', null);

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://cddmksbflgzxmavrddrp.supabase.co',
    publishableKey: 'sb_publishable_TVp222txq_5NUckBeMeK5g_wG5hEY1t',
  );

  runApp(const JagacuanApp());
}

class JagacuanApp extends StatelessWidget {
  const JagacuanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStorageRepository>(
          create: (_) => LocalStorageRepository(),
        ),
        Provider<SupabaseNabarRepository>(
          create: (_) => SupabaseNabarRepository(),
        ),
        ChangeNotifierProvider<TargetListViewModel>(
          create: (context) => TargetListViewModel(
            context.read<LocalStorageRepository>(),
          ),
        ),
      ],
      child: Consumer<TargetListViewModel>(
        builder: (context, vm, _) {
          return MaterialApp(
            title: 'Jagacuan',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: vm.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const TargetListView(),
          );
        },
      ),
    );
  }
}
