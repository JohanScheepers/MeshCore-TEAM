// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
// http://creativecommons.org/licenses/by-nc-sa/4.0/
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import '../database.dart';
import '../tables.dart';
import '../../models/unread_models.dart';

part 'channels_dao.g.dart';

/// DAO for managing mesh network channels
/// Matches Android ChannelDao functionality
@DriftAccessor(tables: [Channels, Messages])
class ChannelsDao extends DatabaseAccessor<AppDatabase>
    with _$ChannelsDaoMixin {
  ChannelsDao(super.db);

  /// Get all channels ordered by channel index
  Future<List<ChannelData>> getAllChannels() {
    return (select(channels)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.channelIndex, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get channels for a specific companion device
  Future<List<ChannelData>> getChannelsByCompanion(String companionKey) {
    return (select(channels)
          ..where((t) => t.companionDeviceKey.equals(companionKey))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.channelIndex, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Get a single channel by hash
  Future<ChannelData?> getChannelByHash(int hash) {
    return (select(channels)..where((t) => t.hash.equals(hash)))
        .getSingleOrNull();
  }

  /// Get a channel by firmware index
  Future<ChannelData?> getChannelByIndex(int index) {
    return (select(channels)..where((t) => t.channelIndex.equals(index)))
        .getSingleOrNull();
  }

  /// Get the public channel (index 0)
  Future<ChannelData?> getPublicChannel() {
    return (select(channels)
          ..where((t) => t.isPublic.equals(true))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get all private channels
  Future<List<ChannelData>> getPrivateChannels() {
    return (select(channels)
          ..where((t) => t.isPublic.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.channelIndex, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Insert or update a channel
  Future<int> upsertChannel(ChannelsCompanion channel) {
    return into(channels).insertOnConflictUpdate(channel);
  }

  /// Update channel name
  Future<void> updateChannelName(int hash, String name) {
    return (update(channels)..where((t) => t.hash.equals(hash)))
        .write(ChannelsCompanion(
      name: Value(name),
    ));
  }

  /// Toggle location sharing for a channel
  Future<void> toggleLocationSharing(int hash, bool shareLocation) {
    return (update(channels)..where((t) => t.hash.equals(hash)))
        .write(ChannelsCompanion(
      shareLocation: Value(shareLocation),
    ));
  }

  /// Set favorite status for a channel
  Future<void> setFavorite(int hash, bool favorite) {
    return (update(channels)..where((t) => t.hash.equals(hash)))
        .write(ChannelsCompanion(isFavorite: Value(favorite)));
  }

  /// Set notification mode for a channel
  Future<void> setNotificationMode(int hash, String mode) {
    return (update(channels)..where((t) => t.hash.equals(hash)))
        .write(ChannelsCompanion(
      notificationMode: Value(mode),
    ));
  }

  /// Delete a channel
  Future<int> deleteChannel(int hash) {
    return (delete(channels)..where((t) => t.hash.equals(hash))).go();
  }

  /// Delete a channel for a specific companion device
  Future<int> deleteChannelForCompanion(int hash, String companionKey) {
    return (delete(channels)
          ..where((t) =>
              t.hash.equals(hash) & t.companionDeviceKey.equals(companionKey)))
        .go();
  }

  /// Delete all channels for a companion device
  Future<int> deleteChannelsByCompanion(String companionKey) {
    return (delete(channels)
          ..where((t) => t.companionDeviceKey.equals(companionKey)))
        .go();
  }

  /// Delete all channels then insert replacements in a single transaction.
  /// Preserves user-set fields (notificationMode, isFavorite) across syncs.
  Future<void> replaceAllChannels(List<ChannelsCompanion> replacements) {
    return db.transaction(() async {
      final existing = await select(channels).get();
      final preserved = {
        for (final c in existing)
          c.hash: (notificationMode: c.notificationMode, isFavorite: c.isFavorite)
      };

      await delete(channels).go();
      for (final channel in replacements) {
        final saved = preserved[channel.hash.value];
        final merged = saved != null
            ? channel.copyWith(
                notificationMode: Value(saved.notificationMode),
                isFavorite: Value(saved.isFavorite),
              )
            : channel;
        await into(channels).insertOnConflictUpdate(merged);
      }
    });
  }

  /// Watch all channels (stream)
  Stream<List<ChannelData>> watchAllChannels() {
    return (select(channels)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.channelIndex, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch channels for a specific companion (stream)
  Stream<List<ChannelData>> watchChannelsByCompanion(String companionKey) {
    return (select(channels)
          ..where((t) => t.companionDeviceKey.equals(companionKey))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.channelIndex, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  /// Watch a single channel by hash (stream)
  Stream<ChannelData?> watchChannel(int hash) {
    return (select(channels)..where((t) => t.hash.equals(hash)))
        .watchSingleOrNull();
  }

  /// Watch the public channel (stream)
  Stream<ChannelData?> watchPublicChannel() {
    return (select(channels)
          ..where((t) => t.isPublic.equals(true))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Get all channels with unread counts, sorted with unread first
  Future<List<ChannelWithUnread>> getAllChannelsWithUnread() async {
    final allChannels = await getAllChannels();
    final channelsWithUnread = <ChannelWithUnread>[];

    for (final channel in allChannels) {
      final unreadCount =
          await db.messagesDao.getUnreadCountByChannel(channel.hash);
      channelsWithUnread.add(ChannelWithUnread(
        channel: channel,
        unreadCount: unreadCount,
      ));
    }

    // Sort by unread count (descending), then by channel index (ascending)
    channelsWithUnread.sort((a, b) {
      if (a.unreadCount != b.unreadCount) {
        return b.unreadCount.compareTo(a.unreadCount);
      }
      return a.channel.channelIndex.compareTo(b.channel.channelIndex);
    });

    return channelsWithUnread;
  }

  Future<List<ChannelWithUnread>> _buildChannelsWithUnread(
      List<ChannelData> channelsList) async {
    final channelsWithUnread = <ChannelWithUnread>[];
    for (final channel in channelsList) {
      final unreadCount =
          await db.messagesDao.getUnreadCountByChannel(channel.hash);
      channelsWithUnread
          .add(ChannelWithUnread(channel: channel, unreadCount: unreadCount));
    }
    channelsWithUnread.sort((a, b) {
      if (a.unreadCount != b.unreadCount) {
        return b.unreadCount.compareTo(a.unreadCount);
      }
      return a.channel.channelIndex.compareTo(b.channel.channelIndex);
    });
    return channelsWithUnread;
  }

  /// Watch all channels with unread counts (stream)
  /// Reacts to changes in both channels and messages tables
  Stream<List<ChannelWithUnread>> watchAllChannelsWithUnread() async* {
    // Yield current state immediately — no debounce for first emit
    yield await _buildChannelsWithUnread(await getAllChannels());

    final controller = StreamController<void>();
    final channelsSub = watchAllChannels().listen((_) {
      if (!controller.isClosed) controller.add(null);
    });
    final messagesSub = db.messagesDao.watchMessageCount().listen((_) {
      if (!controller.isClosed) controller.add(null);
    });

    try {
      await for (final _ in controller.stream
          .debounceTime(const Duration(milliseconds: 500))) {
        yield await _buildChannelsWithUnread(await getAllChannels());
      }
    } finally {
      await channelsSub.cancel();
      await messagesSub.cancel();
      await controller.close();
    }
  }

  /// Watch channels with unread counts for a specific companion device
  Stream<List<ChannelWithUnread>> watchChannelsWithUnreadByCompanion(
      String companionKey) async* {
    // Yield current state immediately — no debounce for first emit
    yield await _buildChannelsWithUnread(
        await getChannelsByCompanion(companionKey));

    final controller = StreamController<void>();
    final channelsSub = watchChannelsByCompanion(companionKey).listen((_) {
      if (!controller.isClosed) controller.add(null);
    });
    final messagesSub = db.messagesDao.watchMessageCount().listen((_) {
      if (!controller.isClosed) controller.add(null);
    });

    try {
      await for (final _ in controller.stream
          .debounceTime(const Duration(milliseconds: 500))) {
        yield await _buildChannelsWithUnread(
            await getChannelsByCompanion(companionKey));
      }
    } finally {
      await channelsSub.cancel();
      await messagesSub.cancel();
      await controller.close();
    }
  }
}
