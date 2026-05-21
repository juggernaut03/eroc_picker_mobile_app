import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'utils/app_constants.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await NotificationService.initSafe();

  // Load cached session BEFORE runApp so auth state is ready when SplashScreen checks it
  final auth = AuthProvider();
  await auth.loadCached();

  runApp(RetailMagicApp(auth: auth));
}

class RetailMagicApp extends StatefulWidget {
  final AuthProvider auth;
  const RetailMagicApp({super.key, required this.auth});

  @override
  State<RetailMagicApp> createState() => _RetailMagicAppState();
}

class _RetailMagicAppState extends State<RetailMagicApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On app resume, re-sync permissions so changes made in the admin panel
    // take effect within seconds. AuthProvider.refresh() is throttled + no-ops
    // when logged out.
    if (state == AppLifecycleState.resumed) {
      widget.auth.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.auth,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
      ),
    );
  }
}

