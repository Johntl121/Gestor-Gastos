import 'package:package_info_plus/package_info_plus.dart';

abstract class AppInfoProvider {
  Future<String> getAppVersion();
}

class AppInfoProviderImpl implements AppInfoProvider {
  @override
  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
