import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managers/routing/app_router.dart';

import 'core/utils/util.dart';
import 'core/theme/theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    TextTheme textTheme = createTextTheme(context, "Roboto", "DM Sans");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp.router(
      title: 'Work Manage',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
