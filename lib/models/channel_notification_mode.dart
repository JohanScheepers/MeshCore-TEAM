// Copyright (c) 2026 tmacinc
// Licensed under CC BY-NC-SA 4.0

enum ChannelNotificationMode {
  normal,
  silent,
  muted;

  static ChannelNotificationMode fromString(String? value) => switch (value) {
        'silent' => silent,
        'muted' => muted,
        _ => normal,
      };

  String toDbString() => name;
}
