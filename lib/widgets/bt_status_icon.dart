// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meshcore_team/models/app_settings.dart';
import 'package:meshcore_team/screens/connection_screen.dart';
import 'package:meshcore_team/services/settings_service.dart';
import 'package:meshcore_team/theme/night_theme.dart';
import 'package:meshcore_team/viewmodels/connection_viewmodel.dart';
import '../l10n/app_localizations.dart';

class BtStatusIcon extends StatelessWidget {
  const BtStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connectionVM = context.watch<ConnectionViewModel>();
    final isConnected = connectionVM.isConnected;
    final isNighttime = context.watch<SettingsService>().settings.appTheme ==
        AppThemeMode.nighttime;

    final color = isNighttime
        ? (isConnected ? NightColors.statusConnected : NightColors.primary)
        : (isConnected ? Colors.blue : Colors.red);

    final icon = Icon(
      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
      color: color,
    );

    // Disconnected: tap opens the connection page.
    if (!isConnected) {
      return Opacity(
        opacity: 0.7,
        child: IconButton(
          tooltip: l10n.notConnected,
          icon: icon,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConnectionScreen()),
          ),
        ),
      );
    }

    // Connected: dropdown with a disconnect action.
    return Opacity(
      opacity: 0.7,
      child: PopupMenuButton<void>(
        tooltip: l10n.connected,
        icon: icon,
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            onTap: () => connectionVM.manualDisconnect(),
            child: ListTile(
              leading: const Icon(Icons.bluetooth_disabled),
              title: Text(l10n.disconnect),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
