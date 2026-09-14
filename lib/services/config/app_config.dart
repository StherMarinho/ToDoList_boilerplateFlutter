import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuração imutável carregada com `--dart-define`.
class AppConfig {
  const AppConfig({
    required this.name,
    required this.meteorUrl,
    required this.meteorDebug,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      name: String.fromEnvironment(
        'APP_NAME',
        defaultValue: 'Synergia Flutter-Meteor Boilerplate',
      ),
      // Endereço do host; dart_meteor normaliza para ws(s) e acrescenta
      // /websocket. 10.0.2.2 é o localhost do host no emulador Android.
      meteorUrl: String.fromEnvironment(
        'METEOR_URL',
        defaultValue: 'http://10.0.2.2:3200',
      ),
      meteorDebug: bool.fromEnvironment('METEOR_DEBUG'),
    );
  }

  final String name;
  final String meteorUrl;
  final bool meteorDebug;

  Uri get meteorUri => Uri.parse(meteorUrl);

  Uri get httpBaseUri {
    final uri = meteorUri;
    final scheme = switch (uri.scheme) {
      'ws' => 'http',
      'wss' => 'https',
      _ => uri.scheme,
    };
    return uri.replace(scheme: scheme, path: '/', query: null, fragment: null);
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});
