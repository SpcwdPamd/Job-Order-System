import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'core/theme/theme_provider.dart';
import 'data/admin_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vztfizlpzyhjzyldkeov.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6dGZpemxwenloanp5bGRrZW92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4NjE0NTcsImV4cCI6MjA5MzQzNzQ1N30.3izru0uS-nD334hCx4p24JA8hM5rEGaJDQL3-7uTdY0',
  );

  await initAdminData();
  runApp(const JobOrderApp());
}

class JobOrderApp extends StatelessWidget {
  const JobOrderApp({super.key});

  @override
  Widget build(BuildContext context) {
    const tk = Tk();
    return TkProvider(
      tk: tk,
      child: MaterialApp(
        title: 'SPCWD Job Order System',
        debugShowCheckedModeBanner: false,
        theme: tk.materialTheme,

        home: const LoginScreen(),
      ),
    );
  }
}