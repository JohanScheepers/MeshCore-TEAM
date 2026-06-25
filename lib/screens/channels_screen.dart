// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:meshcore_team/database/database.dart';
import 'package:meshcore_team/models/unread_models.dart';
import 'package:meshcore_team/repositories/channel_repository.dart';
import 'package:meshcore_team/screens/qr_scan_screen.dart';
import 'package:meshcore_team/models/app_settings.dart';
import 'package:meshcore_team/services/settings_service.dart';
import 'package:meshcore_team/theme/night_theme.dart';
import 'package:meshcore_team/widgets/status_bar_actions.dart';
import 'package:meshcore_team/widgets/night_clock.dart';
import 'channel_chat_screen.dart';

/// Channels Screen
/// Displays list of synced channels from companion device
class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final channelRepository = context.watch<ChannelRepository>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: NightTitle(title: l10n.channels),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addChannelLower,
            onPressed: () => _showAddMenu(context, channelRepository),
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 16, thickness: 1),
          ),
          const StatusBarActions(),
        ],
      ),
      body: StreamBuilder<List<ChannelWithUnread>>(
        stream: channelRepository.watchChannelsWithUnread(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(l10n.genericError(snapshot.error.toString())),
                ],
              ),
            );
          }

          final channelsWithUnread = snapshot.data ?? [];

          if (channelsWithUnread.isEmpty) {
            final emptyColor = Theme.of(context).colorScheme.outline;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: emptyColor),
                  const SizedBox(height: 16),
                  Text(
                    'No channels',
                    style: TextStyle(fontSize: 18, color: emptyColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect to a device and sync to see channels',
                    style: TextStyle(color: emptyColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: channelsWithUnread.length,
            itemBuilder: (context, index) {
              final channelWithUnread = channelsWithUnread[index];
              return ChannelListTile(
                channel: channelWithUnread.channel,
                unreadCount: channelWithUnread.unreadCount,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddMenu(
      BuildContext context, ChannelRepository channelRepository) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(sheetL10n.createPrivateChannel),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCreateChannelDialog(context, channelRepository);
                },
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: Text(sheetL10n.joinHashtagChannel),
                subtitle: Text(sheetL10n.deriveKeyFromName),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showJoinHashtagChannelDialog(context, channelRepository);
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: Text(sheetL10n.addViaLinkQr),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImportChannelDialog(context, channelRepository);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCreateChannelDialog(
      BuildContext context, ChannelRepository channelRepository) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isCreating = false;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> create() async {
              if (isCreating) return;
              setState(() {
                isCreating = true;
              });
              final name = controller.text;
              try {
                final created =
                    await channelRepository.createPrivateChannel(name);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.channelCreated(created.name))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
                if (dialogContext.mounted) {
                  setState(() {
                    isCreating = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(AppLocalizations.of(dialogContext)!.createPrivateChannel),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isCreating,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(dialogContext)!.channelName,
                    ),
                    onSubmitted: (_) => create(),
                  ),
                  if (isCreating) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(dialogContext)!.cancel),
                ),
                FilledButton(
                  onPressed: isCreating ? null : create,
                  child: Text(AppLocalizations.of(dialogContext)!.create),
                ),
              ],
            );
          },
        );
      },
    );
    // Controllers are method-local and will be GC'd; explicit disposal
    // races with the dialog exit animation and causes _dependents.isEmpty
    // assertions, so we intentionally skip it.
  }

  Future<void> _showJoinHashtagChannelDialog(
      BuildContext context, ChannelRepository channelRepository) async {
    final controller = TextEditingController(text: '#');
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isJoining = false;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            Future<void> join() async {
              if (isJoining) return;
              setState(() {
                isJoining = true;
              });
              try {
                final joined =
                    await channelRepository.createHashtagChannel(controller.text);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.channelJoined(joined.name))),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
                if (dialogContext.mounted) {
                  setState(() {
                    isJoining = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: Text(AppLocalizations.of(dialogContext)!.joinHashtagChannel),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isJoining,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(dialogContext)!.channelName,
                      hintText: AppLocalizations.of(dialogContext)!.publicChannelName,
                      helperText:
                          'Anyone who types the same name joins the same channel',
                    ),
                    onSubmitted: (_) => join(),
                  ),
                  if (isJoining) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isJoining ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(dialogContext)!.cancel),
                ),
                FilledButton(
                  onPressed: isJoining ? null : join,
                  child: Text(AppLocalizations.of(dialogContext)!.join),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showImportChannelDialog(
      BuildContext context, ChannelRepository channelRepository) async {
    final nameOrUrlController = TextEditingController();
    final keyOrUrlController = TextEditingController();

    Future<void> runImport(BuildContext dialogContext) async {
      final imported = await channelRepository.importChannel(
        nameOrUrlController.text,
        keyOrUrlController.text,
      );

      if (imported == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.invalidChannelLinkKey)),
          );
        }
        return;
      }

      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.channelAdded(imported.name))),
        );
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(dialogContext)!.addChannel),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameOrUrlController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(dialogContext)!.nameOrLink,
                        hintText: AppLocalizations.of(dialogContext)!.meshcoreChannelAddPlaceholder,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyOrUrlController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(dialogContext)!.secretOrLink,
                        hintText: AppLocalizations.of(dialogContext)!.hexCharsOrBase64,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          final status = await Permission.camera.request();
                          if (!status.isGranted) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(AppLocalizations.of(context)!.cameraPermissionRequired)),
                              );
                            }
                            return;
                          }

                          final scanned = await Navigator.of(context).push(
                            MaterialPageRoute<String>(
                              builder: (_) => QrScanScreen(
                                title: AppLocalizations.of(context)!.scanChannelQr,
                              ),
                            ),
                          );
                          if (scanned == null || scanned.isEmpty) return;

                          // TEAM behavior: if QR is a meshcore URL, import immediately.
                          if (scanned.startsWith('meshcore://channel/add?')) {
                            nameOrUrlController.text = scanned;
                            keyOrUrlController.text = '';
                            setState(() {});
                            await runImport(dialogContext);
                            return;
                          }

                          nameOrUrlController.text = scanned;
                          setState(() {});
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(AppLocalizations.of(dialogContext)!.scanQrCode),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(AppLocalizations.of(dialogContext)!.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      await runImport(dialogContext);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: Text(AppLocalizations.of(dialogContext)!.add),
                ),
              ],
            );
          },
        );
      },
    );
    // Controllers are method-local and will be GC'd; explicit disposal
    // races with the dialog exit animation and causes _dependents.isEmpty
    // assertions, so we intentionally skip it.
  }
}

class ChannelListTile extends StatelessWidget {
  final ChannelData channel;
  final int unreadCount;

  const ChannelListTile({
    super.key,
    required this.channel,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPublic = channel.isPublic;
    final isNighttime = context.watch<SettingsService>().settings.appTheme ==
        AppThemeMode.nighttime;


    // Determine if this channel is the active telemetry channel.
    final settings = context.watch<SettingsService>().settings;
    final telemetryHashHex = settings.telemetryChannelHash;
    int? telemetryHashInt;
    if (telemetryHashHex != null && telemetryHashHex.isNotEmpty) {
      final cleaned =
          telemetryHashHex.trim().toLowerCase().replaceFirst('0x', '');
      telemetryHashInt = int.tryParse(cleaned, radix: 16);
    }
    final isTelemetryChannel =
        settings.telemetryEnabled && channel.hash == telemetryHashInt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isNighttime
                  ? (isPublic ? NightColors.connectStale : NightColors.surfaceHigh)
                  : (isPublic ? Colors.green : Colors.blue),
              child: Icon(
                isPublic ? Icons.public : Icons.lock,
                color: isNighttime ? NightColors.onSurface : Colors.white,
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isNighttime ? NightColors.primary : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: isNighttime ? NightColors.onSurface : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          channel.name.isNotEmpty ? channel.name : 'Unnamed Channel',
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.channelHash(channel.hash.toRadixString(16))),
            Text(l10n.channelIndex(channel.channelIndex.toString())),
            Text(isPublic ? l10n.channelTypePublic : l10n.channelTypePrivate),
            if (channel.muteNotifications) Text(l10n.notificationsMuted),
            if (isTelemetryChannel)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 14,
                      color: isNighttime ? NightColors.primary : Colors.blue),
                  const SizedBox(width: 2),
                  Text(l10n.locationSharingOn),
                ],
              )
            else if (!settings.telemetryEnabled &&
                channel.hash == telemetryHashInt)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off,
                      size: 14,
                      color: isNighttime
                          ? NightColors.dimmer
                          : Colors.grey),
                  const SizedBox(width: 2),
                  Text(l10n.locationSharingOff),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.group,
                  color: isNighttime
                      ? (isPublic ? NightColors.connectStale : NightColors.onSurfaceVariant)
                      : (isPublic ? Colors.green : Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ch${channel.channelIndex}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (!isPublic) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: l10n.channelActions,
                onSelected: (value) async {
                  if (value != 'delete') return;

                  final repo = context.read<ChannelRepository>();

                  await showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogContext) {
                      bool isDeleting = false;
                      return StatefulBuilder(
                        builder: (dialogContext, setState) {
                          Future<void> doDelete() async {
                            if (isDeleting) return;
                            setState(() => isDeleting = true);
                            try {
                              await repo.deletePrivateChannel(channel);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(AppLocalizations.of(context)!.channelDeleted(channel.name))),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                              if (dialogContext.mounted) {
                                setState(() => isDeleting = false);
                              }
                            }
                          }

                          return AlertDialog(
                            title: Text(AppLocalizations.of(dialogContext)!.deleteChannel),
                            content: Text(
                              'Delete "${channel.name}" from the companion and this phone?\n\nThis cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: isDeleting
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                child: Text(AppLocalizations.of(dialogContext)!.cancel),
                              ),
                              FilledButton(
                                onPressed: isDeleting ? null : doDelete,
                                child: isDeleting
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(AppLocalizations.of(dialogContext)!.delete),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(AppLocalizations.of(context)!.delete),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChannelChatScreen(channel: channel),
            ),
          );
        },
      ),
    );
  }

}
