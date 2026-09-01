// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0
//
// This file is part of TEAM-Flutter.
// Non-commercial use only. See LICENSE file for details.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/app_language.dart';
import '../services/settings_service.dart';

/// First-launch language picker, shown once by `_LanguageGate` before the
/// permission screen.
///
/// Languages are listed by endonym (Deutsch, not German) so every entry is
/// legible no matter which locale is currently active. Selecting one applies it
/// immediately rather than on Continue — the screen relocalizing under the
/// user's finger is the confirmation that the choice took effect.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  /// An [AppLanguage.code], or [AppLanguage.systemDefault].
  String? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preselect the language the app already resolved to — the device's, when
    // we translate it, else English via _resolveLocale. Seeded once: this runs
    // again on every locale change, and re-seeding would fight the selection.
    _selected ??= Localizations.localeOf(context).languageCode;
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    await context.read<SettingsService>().setLocaleCode(code);
  }

  Future<void> _confirm() async {
    // Persist the shown selection before flipping the gate. Usually a no-op —
    // _select already wrote it — but it also covers Continue being tapped
    // without touching the radios, where the preselected language was only
    // ever local state and settings still held the systemDefault sentinel.
    // Without this the picker would show "Italiano" while Settings afterwards
    // showed "Use device language".
    final settings = context.read<SettingsService>();
    await settings.setLocaleCode(_selected!);
    await settings.setLanguageChosen(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Icon(Icons.language,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.chooseLanguage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final language in AppLanguage.all)
                    RadioListTile<String>(
                      title: Text(language.endonym),
                      value: language.code,
                      groupValue: _selected,
                      onChanged: (v) => _select(v!),
                    ),
                  const Divider(height: 24),
                  RadioListTile<String>(
                    title: Text(l10n.languageDeviceDefault),
                    value: AppLanguage.systemDefault,
                    groupValue: _selected,
                    onChanged: (v) => _select(v!),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.continue_),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
