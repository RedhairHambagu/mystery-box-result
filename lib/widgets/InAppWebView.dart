import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  InAppWebViewController? _controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login to Weidian')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri('https://sso.weidian.com/login/index.php')),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          // ... other settings as needed ...
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
        },
        onLoadStop: (controller, url) async {
          // You can listen for URL changes or specific events to detect login success
          if (url.toString().contains('success_redirect_url') || url.toString().contains('logged_in')) {
            print('Login might be complete! Current URL: $url');
            // Now, you can try to extract cookies from this visible WebView
            final cookies = await CookieManager.instance().getCookies(url: url!);
            final cookieMap = <String, String>{};
            for (final cookie in cookies) {
              cookieMap[cookie.name] = cookie.value;
            }
            print('Cookies after potential login: $cookieMap');
            // You can then navigate back or close this view
            Navigator.of(context).pop(cookieMap); // Pass cookies back to previous screen
          }
        },
        // ... other callbacks for error handling, console messages, etc.
      ),
    );
  }
}