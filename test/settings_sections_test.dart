// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_team/screens/settings_screen.dart';
import 'package:meshcore_team/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsService> _service([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SettingsService(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collapsed settings sections', () {
    test('every section starts expanded', () async {
      final settings = await _service();
      expect(settings.settings.collapsedSettingsSections, isEmpty);
    });

    test('collapsing and expanding round-trips', () async {
      final settings = await _service();

      await settings.setSettingsSectionCollapsed(SettingsSection.data, true);
      expect(settings.settings.collapsedSettingsSections,
          contains(SettingsSection.data));

      await settings.setSettingsSectionCollapsed(SettingsSection.data, false);
      expect(settings.settings.collapsedSettingsSections,
          isNot(contains(SettingsSection.data)));
    });

    test('sections collapse independently', () async {
      final settings = await _service();

      await settings.setSettingsSectionCollapsed(SettingsSection.data, true);
      await settings.setSettingsSectionCollapsed(SettingsSection.location, true);
      await settings.setSettingsSectionCollapsed(SettingsSection.data, false);

      expect(settings.settings.collapsedSettingsSections,
          [SettingsSection.location]);
    });

    test('collapsing twice does not duplicate the id', () async {
      final settings = await _service();

      await settings.setSettingsSectionCollapsed(SettingsSection.android, true);
      await settings.setSettingsSectionCollapsed(SettingsSection.android, true);

      expect(settings.settings.collapsedSettingsSections,
          [SettingsSection.android]);
    });

    test('expanding an already-expanded section is a no-op', () async {
      final settings = await _service();
      var notifications = 0;
      settings.addListener(() => notifications++);

      await settings
          .setSettingsSectionCollapsed(SettingsSection.appearance, false);

      expect(settings.settings.collapsedSettingsSections, isEmpty);
      expect(notifications, 0);
    });

    test('collapse state survives a restart', () async {
      final settings = await _service();
      await settings
          .setSettingsSectionCollapsed(SettingsSection.appearance, true);

      // A fresh service over the same prefs — as on the next app launch.
      final reloaded =
          SettingsService(await SharedPreferences.getInstance());
      expect(reloaded.settings.collapsedSettingsSections,
          [SettingsSection.appearance]);
    });

    test('a section absent from stored state defaults to expanded', () async {
      // Simulates upgrading into a release that adds a new section: only the
      // old ids are stored, and the new one must not come up hidden.
      final settings = await _service({
        'collapsed_settings_sections': <String>[SettingsSection.data],
      });

      expect(settings.settings.collapsedSettingsSections,
          isNot(contains(SettingsSection.appearance)));
      expect(settings.settings.collapsedSettingsSections,
          contains(SettingsSection.data));
    });
  });
}
