import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'force_update_client.dart';

/// A widget that checks for and enforces a forced upgrade for the app.
///
/// It monitors the app's lifecycle and uses [ForceUpdateClient] to determine whether an update
/// is necessary. If so, it displays an alert dialog prompting the user to update, and upon confirmation,
/// navigates to the appropriate app store listing.
///
/// **Usage:**
/// Wrap your app's main content with [ForceUpdateWidget] to ensure that a forced update is triggered
/// when required.
class ForceUpdateWidget extends StatefulWidget {
  /// Creates a [ForceUpdateWidget] with the necessary parameters.
  ///
  /// [navigatorKey] provides access to the Navigator context.
  /// [forceUpdateClient] is the client that determines if an update is required.
  /// [allowCancel] specifies whether the user can cancel the update prompt.
  /// [showForceUpdateAlert] is a callback that displays the update alert dialog.
  /// [showStoreListing] is a callback that opens the app store listing.
  /// [onException] is an optional handler for errors during update checks.
  /// [child] is the widget displayed when no forced update is necessary.
  const ForceUpdateWidget({
    super.key,
    required this.navigatorKey,
    required this.forceUpdateClient,
    required this.allowCancel,
    required this.showForceUpdateAlert,
    required this.showStoreListing,
    this.onException,
    required this.child,
  });

  /// Key used to access the Navigator's context.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Client that determines if a forced update is necessary.
  final ForceUpdateClient forceUpdateClient;

  /// Flag indicating whether the user is allowed to cancel the update prompt.
  final bool allowCancel;

  /// Callback function to display the forced update alert dialog.
  /// Returns a [Future<bool?>] indicating the user's decision.
  final Future<bool?> Function(BuildContext context, bool allowCancel)
      showForceUpdateAlert;

  /// Callback function to open the store listing URL.
  final Future<void> Function(Uri storeUrl) showStoreListing;

  /// Optional error handler for exceptions during update checks.
  final void Function(Object error, StackTrace? stackTrace)? onException;

  /// Child widget to display if no forced upgrade is required.
  final Widget child;

  @override
  State<ForceUpdateWidget> createState() => _ForceUpdateWidgetState();
}

class _ForceUpdateWidgetState extends State<ForceUpdateWidget>
    with WidgetsBindingObserver {
  /// Tracks whether the update alert is currently visible.
  bool _isAlertVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check for forced app update.
    // ignore: discarded_futures
    _checkIfAppUpdateIsNeeded();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // When the app resumes, check if an update is required.
    if (state == AppLifecycleState.resumed) {
      await _checkIfAppUpdateIsNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Checks whether a forced app update is needed and triggers the update process if required.
  Future<void> _checkIfAppUpdateIsNeeded() async {
    if (_isAlertVisible) {
      return;
    }
    try {
      final storeUrl = await widget.forceUpdateClient.storeUrl();
      if (storeUrl == null) {
        return;
      }
      final updateRequired =
          await widget.forceUpdateClient.isAppUpdateRequired();
      if (updateRequired) {
        await _triggerForceUpdate(Uri.parse(storeUrl));
      }
    } catch (e, st) {
      final handler = widget.onException;
      if (handler != null) {
        handler.call(e, st);
      } else {
        rethrow;
      }
    }
  }

  /// Triggers the forced update process by repeatedly showing the update alert until a clear decision is made.
  ///
  /// If the user agrees to update (returns `true`), the store listing is opened.
  /// If the user cancels (returns `false`) or if cancellation is allowed, the process stops.
  Future<void> _triggerForceUpdate(Uri storeUrl) async {
    final ctx = widget.navigatorKey.currentContext ?? context;
    bool? success;
    // Loop until a clear decision is made.
    while (true) {
      setState(() {
        _isAlertVisible = true;
      });
      success = await widget.showForceUpdateAlert(ctx, widget.allowCancel);
      setState(() {
        _isAlertVisible = false;
      });
      if (success == true) {
        await widget.showStoreListing(storeUrl);
        break;
      } else if (success == false) {
        // User canceled the update prompt.
        break;
      } else if (success == null && !widget.allowCancel) {
        // If cancellation is not allowed (e.g., Android back button), repeat the prompt.
        continue;
      } else {
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
