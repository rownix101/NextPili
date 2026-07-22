import 'dart:convert' show base64, jsonDecode, jsonEncode, utf8;
import 'dart:io' show HttpClient, Platform;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'geetest_result.dart';

/// Shared Windows WebView2 environment (set from [main] when available).
WebViewEnvironment? geetestWebViewEnvironment;

/// Embedded GeeTest fullpage dialog (ported from PiliPlus).
///
/// - Linux: native window via `desktop_webview_window`
/// - Other platforms: `flutter_inappwebview`
class GeetestWebviewDialog extends StatefulWidget {
  const GeetestWebviewDialog({
    super.key,
    required this.gt,
    required this.challenge,
  });

  final String gt;
  final String challenge;

  /// Show dialog and return validate payload, or `null` if cancelled / failed.
  static Future<GeetestResult?> show({
    required BuildContext context,
    required String gt,
    required String challenge,
  }) {
    return showDialog<GeetestResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GeetestWebviewDialog(gt: gt, challenge: challenge),
    );
  }

  @override
  State<GeetestWebviewDialog> createState() => _GeetestWebviewDialogState();
}

class _GeetestWebviewDialogState extends State<GeetestWebviewDialog> {
  static const _geetestJsUri =
      'https://static.geetest.com/static/js/fullpage.0.0.0.js';

  late final Future<_ConfigState> _future;
  Webview? _linuxWebview;
  var _linuxWebviewLoading = true;

  static String _showJs(String response) =>
      't=Geetest($response).onSuccess(()=>R("success",t.getValidate())).onError(o=>R("error",o)).onClose(o=>R("close",o));t.onReady(()=>t.verify())';

  bool get _useLinuxNativeWindow =>
      !kIsWeb && Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _future = _getConfig(widget.gt, widget.challenge);
    if (_useLinuxNativeWindow) {
      _initLinuxWebview();
    }
  }

  static Future<_ConfigState> _getConfig(String gt, String challenge) async {
    final client = HttpClient();
    try {
      final uri = Uri.https('api.geetest.com', '/gettype.php', {'gt': gt});
      final req = await client.getUrl(uri);
      final res = await req.close();
      final data = await res.transform(utf8.decoder).join();
      if (data.startsWith('(') && data.endsWith(')')) {
        final Map<String, dynamic> config;
        try {
          config = jsonDecode(data.substring(1, data.length - 1))
              as Map<String, dynamic>;
        } catch (e) {
          return _ConfigState.error(e.toString());
        }
        if (config['status'] == 'success') {
          final payload = Map<String, dynamic>.from(
            config['data'] as Map<String, dynamic>,
          )..addAll({
              'gt': gt,
              'challenge': challenge,
              'offline': false,
              'new_captcha': true,
              'product': 'bind',
              'width': '100%',
              'https': true,
              'protocol': 'https://',
            });
          return _ConfigState.ok(jsonEncode(payload));
        }
        return _ConfigState.error(data);
      }
      return _ConfigState.error(data.isEmpty ? 'empty gettype response' : data);
    } catch (e) {
      return _ConfigState.error(e.toString());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _initLinuxWebview() async {
    final config = await _future;
    if (!mounted) return;

    if (!config.isOk) {
      _popError(config.error ?? 'geetest config failed');
      return;
    }

    final response = config.response!;
    _linuxWebview = await WebviewWindow.create(
      configuration: const CreateConfiguration(
        windowWidth: 300,
        windowHeight: 400,
        title: '验证码',
      ),
    );

    if (!mounted) {
      _closeLinuxWebview();
      return;
    }

    _linuxWebview!.addOnWebMessageReceivedCallback((msg) {
      final msgStr = msg.toString();
      if (msgStr.startsWith('success:')) {
        final dataStr = msgStr.substring('success:'.length);
        final result = GeetestResult.tryParse(dataStr);
        if (result != null && mounted) {
          Navigator.of(context).pop(result);
          return;
        }
        debugPrint(
          'geetest linux success parse failed: type=${dataStr.runtimeType} raw=$dataStr',
        );
      } else if (msgStr.startsWith('error:')) {
        debugPrint('geetest error: $msgStr');
      } else if (msgStr.startsWith('close:')) {
        if (mounted) Navigator.of(context).pop();
      }
    });

    _linuxWebview!.onClose.whenComplete(() {
      if (mounted) Navigator.of(context).pop();
    });

    final html = '''
<!DOCTYPE html><html><head></head><body>
<script src="$_geetestJsUri"></script>
<script>
  R=(n,o)=>webkit.messageHandlers.msgToNative.postMessage(n+':'+JSON.stringify(o))
  ${_showJs(response)}
</script>
</body></html>
''';

    _linuxWebview!.launch(
      'data:text/html;base64,${base64.encode(utf8.encode(html))}',
    );

    if (mounted) {
      setState(() => _linuxWebviewLoading = false);
    }
  }

  void _closeLinuxWebview() {
    _linuxWebview?.close();
    _linuxWebview = null;
  }

  void _popError(String message) {
    debugPrint('geetest: $message');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _closeLinuxWebview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useLinuxNativeWindow) {
      return AlertDialog(
        title: const Text('验证码'),
        content: SizedBox(
          width: 300,
          height: 120,
          child: Center(
            child: _linuxWebviewLoading
                ? const CircularProgressIndicator()
                : const Text('请在弹出的新窗口中完成验证'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ],
      );
    }

    return Dialog.fullscreen(
      child: Stack(
        children: [
          InAppWebView(
            webViewEnvironment: geetestWebViewEnvironment,
            initialSettings: InAppWebViewSettings(
              clearCache: true,
              javaScriptEnabled: true,
              forceDark: ForceDark.AUTO,
              useHybridComposition: false,
              algorithmicDarkeningAllowed: true,
              useShouldOverrideUrlLoading: true,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36',
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              incognito: true,
              allowFileAccess: false,
              allowsLinkPreview: false,
              allowContentAccess: false,
              useOnDownloadStart: false,
              geolocationEnabled: false,
              thirdPartyCookiesEnabled: false,
              enterpriseAuthenticationAppLinkPolicyEnabled: false,
              saveFormData: false,
              safeBrowsingEnabled: false,
              isFraudulentWebsiteWarningEnabled: false,
              domStorageEnabled: false,
              databaseEnabled: false,
              cacheEnabled: false,
              cacheMode: CacheMode.LOAD_NO_CACHE,
              horizontalScrollBarEnabled: false,
              verticalScrollBarEnabled: false,
              overScrollMode: OverScrollMode.NEVER,
              pageZoom: !kIsWeb && Platform.isIOS ? 3 : 1,
            ),
            initialData: InAppWebViewInitialData(
              data:
                  '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width"></head><body><script src="$_geetestJsUri"></script><script>R=flutter_inappwebview.callHandler</script></body></html>',
            ),
            onWebViewCreated: (ctr) {
              ctr
                ..addJavaScriptHandler(
                  handlerName: 'success',
                  callback: (args) {
                    Object? payload;
                    if (args.isNotEmpty) {
                      payload = args[0];
                    }
                    // Some platform bridges pass the map as the only element;
                    // others wrap [name, data] or stringify once.
                    final result = GeetestResult.tryParse(payload) ??
                        (args.length > 1
                            ? GeetestResult.tryParse(args[1])
                            : null) ??
                        GeetestResult.tryParse(args);
                    if (result != null && mounted) {
                      Navigator.of(context).pop(result);
                      return;
                    }
                    debugPrint(
                      'geetest invalid result: types='
                      '${args.map((e) => e.runtimeType).toList()} args=$args',
                    );
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'error',
                  callback: (args) {
                    debugPrint('geetest error: $args');
                  },
                )
                ..addJavaScriptHandler(
                  handlerName: 'close',
                  callback: (args) {
                    if (mounted) Navigator.of(context).pop();
                  },
                );
            },
            onLoadStop: (ctr, _) async {
              final config = await _future;
              if (!mounted) return;
              if (config.isOk) {
                await ctr.evaluateJavascript(source: _showJs(config.response!));
              } else {
                _popError(config.error ?? 'geetest config failed');
              }
            },
          ),
          Positioned(
            left: 8,
            top: MediaQuery.paddingOf(context).top + 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '关闭',
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigState {
  const _ConfigState._({this.response, this.error});

  factory _ConfigState.ok(String response) =>
      _ConfigState._(response: response);

  factory _ConfigState.error(String error) => _ConfigState._(error: error);

  final String? response;
  final String? error;

  bool get isOk => response != null;
}
