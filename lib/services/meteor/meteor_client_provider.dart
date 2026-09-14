import 'package:dart_meteor/dart_meteor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synergia_flutter_meteor_boilerplate/services/config/app_config.dart';

final meteorClientProvider = Provider<MeteorClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = MeteorClient.connect(
    url: config.meteorUrl,
    debug: config.meteorDebug,
    userAgent: 'SynergiaFlutterMeteorBoilerplate/1.0',
  );

  ref.onDispose(client.disconnect);
  return client;
});
