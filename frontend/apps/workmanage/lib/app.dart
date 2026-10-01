import 'package:flutter/material.dart';
//import 'package:managers/ui/auth/widgets/login_screen.dart';
import 'package:managers/ui/register/widget/register_screen.dart';


import 'utils/util.dart';
import 'ui/core/theme/theme.dart';

class App extends StatelessWidget {


  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    TextTheme textTheme = createTextTheme(context, "Roboto", "DM Sans");
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      title: 'Work Manage',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      initialRoute: '/',
      routes: {
        //'/': (context) => LoginScreen(),
        '/': (context) => RegisterScreen(),
      },
    );
  }
}
