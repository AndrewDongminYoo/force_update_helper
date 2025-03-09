import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

import 'platform_utils.dart';

/// A client that checks whether a forced upgrade is required for the app.
///
/// It compares the current app version with the required version fetched from a remote source.
/// Additionally, it generates the appropriate app store URL based on the current platform.
class ForceUpdateClient {
  /// Creates a [ForceUpdateClient] with the provided parameters.
  ///
  /// [fetchRequiredVersion] is a callback to asynchronously retrieve the required version string.
  /// [iosAppStoreId] is the identifier used to build the iOS App Store URL.
  const ForceUpdateClient({
    required this.fetchRequiredVersion,
    required this.iosAppStoreId,
  });

  /// Asynchronous function to fetch the required version string.
  final AsyncValueGetter<String> fetchRequiredVersion;

  /// iOS App Store ID used to build the store URL for iOS.
  final String iosAppStoreId;

  static const _name = 'force_update';
  static const _storeUrlApple = 'https://apps.apple.com/app/id';
  static const _storeUrlGoogle =
      'https://play.google.com/store/apps/details?id=';

  // Static cache for PackageInfo to avoid repeated asynchronous calls.
  static Future<PackageInfo>? _cachedPackageInfo;
  static Future<PackageInfo> get _packageInfo async {
    _cachedPackageInfo ??= PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  /// Checks whether a forced app update is required.
  ///
  /// Retrieves the required version via [fetchRequiredVersion] and compares it to the current
  /// version (extracted from [PackageInfo]). Returns `true` if an update is needed, `false` otherwise.
  ///
  /// This method applies only for iOS and Android platforms.
  Future<bool> isAppUpdateRequired() async {
    // Only force app update on iOS & Android.
    if (PlatformUtil.isWeb ||
        (!PlatformUtil.isIOS && !PlatformUtil.isAndroid)) {
      return false;
    }
    final requireVersionStr = await fetchRequiredVersion();
    if (requireVersionStr.isEmpty) {
      log('Remote Config: required_version not set. Ignoring.', name: _name);
      return false;
    }

    final packageInfo = await _packageInfo;

    // Safely extract version using regex.
    final versionMatch =
        RegExp(r'\d+\.\d+\.\d+').matchAsPrefix(packageInfo.version);
    if (versionMatch == null) {
      log('Could not extract a valid version from ${packageInfo.version}',
          name: _name);
      return false;
    }
    final currentVersionStr = versionMatch.group(0)!;

    try {
      // Parse versions in semver format.
      final requireVersion = Version.parse(requireVersionStr);
      final currentVersion = Version.parse(currentVersionStr);

      final updateRequired = currentVersion < requireVersion;
      log(
        'Update ${updateRequired ? '' : 'not '}required. '
        'Current version: $currentVersion, required version: $requireVersion',
        name: _name,
      );
      return updateRequired;
    } on FormatException catch (e) {
      log('Version parsing failed: ${e.message}', name: _name);
      return false;
    } catch (e) {
      log('Unexpected error during version comparison: $e', name: _name);
      return false;
    }
  }

  /// Generates and returns the appropriate store URL based on the current platform.
  ///
  /// For iOS, the URL is constructed using the provided [iosAppStoreId]. For Android, it
  /// uses the package name from [PackageInfo]. Returns `null` if the platform is unsupported.
  Future<String?> storeUrl() async {
    if (PlatformUtil.isWeb) {
      return null;
    } else if (PlatformUtil.isIOS) {
      // On iOS, use the given app ID.
      return iosAppStoreId.isNotEmpty ? _storeUrlApple + iosAppStoreId : null;
    } else if (PlatformUtil.isAndroid) {
      final packageInfo = await _packageInfo;
      // On Android, use the package name from PackageInfo.
      return _storeUrlGoogle + packageInfo.packageName;
    } else {
      log('No store URL for platform: ${defaultTargetPlatform.name}',
          name: _name);
      return null;
    }
  }
}
