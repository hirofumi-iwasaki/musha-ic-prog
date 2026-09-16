// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/models/device_catalog.dart';

final class MiniproDeviceCatalogLoader {
  static const assetPath = 'assets/minipro/device_catalog.json';

  Future<DeviceCatalog> load() async {
    final source = await rootBundle.loadString(assetPath);
    return compute(_parseCatalog, source);
  }
}

DeviceCatalog _parseCatalog(String source) =>
    DeviceCatalog.fromJsonString(source);
