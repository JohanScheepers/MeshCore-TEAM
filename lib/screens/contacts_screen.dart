// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meshcore_team/database/database.dart';
import '../l10n/app_localizations.dart';
import 'package:meshcore_team/models/unread_models.dart';
import 'package:meshcore_team/repositories/contact_repository.dart';
import 'package:meshcore_team/models/app_settings.dart';
import 'package:meshcore_team/services/settings_service.dart';
import 'package:meshcore_team/theme/night_theme.dart';
import 'package:meshcore_team/widgets/status_bar_actions.dart';
import 'package:meshcore_team/widgets/night_clock.dart';
import 'direct_message_screen.dart';

enum _ContactFilter { endNodes, repeaters, hasLocation, noLocation, favorites }

enum _SortOrder { lastSeen, name, favoritesFirst }

/// Contacts Screen
/// Displays list of synced contacts from companion device
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  Set<_ContactFilter> _filter = {};
  _SortOrder _sort = _SortOrder.lastSeen;
  bool _searching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ContactWithUnread> _applyFilterAndSort(List<ContactWithUnread> all) {
    // Type chips (End Nodes, Repeaters) are OR'd; Favorites is AND'd on top.
    final hasType = _filter.contains(_ContactFilter.endNodes) ||
        _filter.contains(_ContactFilter.repeaters);

    final typeFiltered = hasType
        ? all.where((c) {
            if (_filter.contains(_ContactFilter.endNodes) && !c.contact.isRepeater) return true;
            if (_filter.contains(_ContactFilter.repeaters) && c.contact.isRepeater) return true;
            return false;
          }).toList()
        : all;

    final hasLoc = _filter.contains(_ContactFilter.hasLocation);
    final noLoc = _filter.contains(_ContactFilter.noLocation);
    final locFiltered = (hasLoc || noLoc) && !(hasLoc && noLoc)
        ? typeFiltered.where((c) {
            final loc = c.contact.latitude != null;
            return hasLoc ? loc : !loc;
          }).toList()
        : typeFiltered;

    final filtered = _filter.contains(_ContactFilter.favorites)
        ? locFiltered.where((c) => c.contact.isFavorite).toList()
        : locFiltered;

    final q = _searchQuery.trim().toLowerCase();
    final searched = q.isEmpty
        ? filtered
        : filtered.where((c) {
            final name = (c.contact.name ?? '').toLowerCase();
            final hash = c.contact.hash.toRadixString(16).toLowerCase();
            return name.contains(q) || hash.contains(q);
          }).toList();

    if (_sort == _SortOrder.lastSeen) return searched;

    final sorted = [...searched];
    if (_sort == _SortOrder.name) {
      sorted.sort((a, b) {
        final aName = (a.contact.name ?? '').toLowerCase();
        final bName = (b.contact.name ?? '').toLowerCase();
        return aName.compareTo(bName);
      });
    } else if (_sort == _SortOrder.favoritesFirst) {
      sorted.sort((a, b) {
        if (a.contact.isFavorite == b.contact.isFavorite) return 0;
        return a.contact.isFavorite ? -1 : 1;
      });
    }
    return sorted;
  }

  void _cycleSortOrder() {
    setState(() {
      _sort = switch (_sort) {
        _SortOrder.lastSeen => _SortOrder.name,
        _SortOrder.name => _SortOrder.favoritesFirst,
        _SortOrder.favoritesFirst => _SortOrder.lastSeen,
      };
    });
  }

  IconData _sortIcon() => switch (_sort) {
    _SortOrder.lastSeen => Icons.access_time,
    _SortOrder.name => Icons.sort_by_alpha,
    _SortOrder.favoritesFirst => Icons.star,
  };

  String _sortTooltip(AppLocalizations l10n) => switch (_sort) {
    _SortOrder.lastSeen => l10n.sortByLastSeen,
    _SortOrder.name => l10n.sortByName,
    _SortOrder.favoritesFirst => l10n.sortByFavorites,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contactRepository = context.watch<ContactRepository>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: NightTitle(title: l10n.contacts),
        actions: [
          IconButton(
            icon: Icon(_sortIcon()),
            tooltip: _sortTooltip(l10n),
            onPressed: _cycleSortOrder,
          ),
          const SizedBox(
            height: 24,
            child: VerticalDivider(width: 16, thickness: 1),
          ),
          const StatusBarActions(),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(l10n),
          Expanded(
            child: StreamBuilder<List<ContactWithUnread>>(
              stream: contactRepository.watchContactsWithUnread(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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

                final all = snapshot.data ?? [];
                final contacts = _applyFilterAndSort(all);

                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noContacts,
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.connectToDeviceToSeeContacts,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noContactsMatchFilter,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contactWithUnread = contacts[index];
                    return ContactListTile(
                      contact: contactWithUnread.contact,
                      unreadCount: contactWithUnread.unreadCount,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n) {
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.search,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _searching = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ],
        ),
      );
    }

    final anyActive = _filter.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: () => setState(() => _searching = true),
          ),
          SegmentedButton<_ContactFilter>(
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _ContactFilter.endNodes,
            icon: const Icon(Icons.person, size: 16),
            tooltip: l10n.filterEndNodes,
          ),
          ButtonSegment(
            value: _ContactFilter.repeaters,
            icon: const Icon(Icons.device_hub, size: 16),
            tooltip: l10n.filterRepeaters,
          ),
          ButtonSegment(
            value: _ContactFilter.hasLocation,
            icon: const Icon(Icons.location_on, size: 16),
            tooltip: l10n.filterHasLocation,
          ),
          ButtonSegment(
            value: _ContactFilter.noLocation,
            icon: const Icon(Icons.location_off, size: 16),
            tooltip: l10n.filterNoLocation,
          ),
          ButtonSegment(
            value: _ContactFilter.favorites,
            icon: const Icon(Icons.star, size: 16),
          ),
        ],
        selected: _filter,
        onSelectionChanged: (s) => setState(() => _filter = s),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: anyActive ? () => setState(() => _filter = {}) : null,
              child: Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: anyActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.filter_alt_off,
                  size: 18,
                  color: anyActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContactListTile extends StatelessWidget {
  final ContactData contact;
  final int unreadCount;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final contactRepository = context.read<ContactRepository>();
    final hasLocation = contact.latitude != null && contact.longitude != null;
    final lastSeenText = _formatLastSeen(contact.lastSeen);
    final isNighttime = context.watch<SettingsService>().settings.appTheme ==
        AppThemeMode.nighttime;

    final minutesSinceLastSeen =
        (DateTime.now().millisecondsSinceEpoch - contact.lastSeen).toDouble();
    final connectivityColor =
        _getConnectivityColor(minutesSinceLastSeen.toInt(), isNighttime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: connectivityColor,
              child: Text(
                contact.name?.isNotEmpty == true
                    ? contact.name!.substring(0, 1).toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isNighttime ? NightColors.onSurface : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isNighttime
                      ? NightColors.onSurfaceVariant
                      : Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  contact.isRepeater ? Icons.device_hub : Icons.person,
                  size: 13,
                  color: isNighttime ? NightColors.surface : Colors.white,
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact.name ?? l10n.unknown,
                style: TextStyle(
                  fontWeight:
                      unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (contact.isRepeater)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  l10n.repeaterLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.channelHash(contact.hash.toRadixString(16))),
            Text(l10n.lastSeen(lastSeenText)),
            if (hasLocation)
              Text(l10n.locationCoordinates(
                  contact.latitude!.toStringAsFixed(4),
                  contact.longitude!.toStringAsFixed(4))),
            if (contact.companionBatteryMilliVolts != null)
              Text(l10n.batteryVoltage(
                  (contact.companionBatteryMilliVolts! / 1000)
                      .toStringAsFixed(2))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => contactRepository.setFavorite(
                  contact.publicKey, !contact.isFavorite),
              child: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite
                    ? (isNighttime ? NightColors.primary : Colors.amber)
                    : (isNighttime ? NightColors.dimmer : Colors.grey),
                size: 22,
              ),
            ),
            const SizedBox(width: 4),
            hasLocation
                ? Icon(Icons.location_on,
                    color: isNighttime ? NightColors.primary : Colors.blue)
                : Icon(Icons.location_off,
                    color: isNighttime ? NightColors.dimmer : Colors.grey),
          ],
        ),
        onTap: () {
          if (contact.isRepeater) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.directMessagesDisabledForRepeaters),
              ),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DirectMessageScreen(contact: contact),
            ),
          );
        },
      ),
    );
  }

  String _formatLastSeen(int timestamp) {
    final lastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Color _getConnectivityColor(int millisSinceLastSeen, bool isNighttime) {
    final minutesSince = millisSinceLastSeen / 60000.0;

    if (isNighttime) {
      if (minutesSince < 1) return NightColors.connectJustSeen;
      if (minutesSince < 5) return NightColors.connectRecent;
      if (minutesSince < 10) return NightColors.connectStale;
      if (minutesSince < 30) return NightColors.connectOffline;
      return NightColors.connectOutOfRange;
    }

    if (minutesSince < 1) return Colors.green;
    if (minutesSince < 5) return Colors.yellow;
    if (minutesSince < 10) return Colors.orange;
    if (minutesSince < 30) return Colors.red;
    return Colors.grey;
  }
}
