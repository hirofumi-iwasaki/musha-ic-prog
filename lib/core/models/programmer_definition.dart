// SPDX-License-Identifier: GPL-3.0-or-later

/// Stable identities for programmer models. These identify the physical model,
/// rather than a USB product ID, because several newer models share one ID.
enum ProgrammerId { tl866cs, tl866a, tl866iiPlus, t48, t56, t76 }

enum ProgrammerCapability { read, blankCheck, program, verify }

/// Immutable model-specific facts used by catalog, profile, and backend code.
///
/// Definitions can exist before a model is enabled in the product. [enabled]
/// keeps those future models out of the selectable model list.
final class ProgrammerDefinition {
  const ProgrammerDefinition({
    required this.id,
    required this.displayName,
    required this.databaseTypes,
    required this.miniproModelName,
    required this.expectedHardwareModel,
    required this.usbDeviceIds,
    required this.capabilities,
    this.infoic2PlusPinMapBit,
    this.enabled = false,
  });

  final ProgrammerId id;
  final String displayName;
  final Set<String> databaseTypes;

  /// minipro's database selector, not evidence of an attached USB model.
  final String miniproModelName;
  final String expectedHardwareModel;
  final Set<String> usbDeviceIds;

  /// Compatibility spelling for callers that describe the IDs explicitly.
  Set<String> get usbVendorProductIds => usbDeviceIds;
  final Set<ProgrammerCapability> capabilities;

  /// The INFOIC2PLUS model bit, when that shared database has one.
  final int? infoic2PlusPinMapBit;
  final bool enabled;

  bool get usesInfoic2Plus => databaseTypes.contains('INFOIC2PLUS');

  bool supports(ProgrammerCapability capability) =>
      capabilities.contains(capability);

  static const tl866cs = ProgrammerDefinitions.tl866cs;
  static const tl866a = ProgrammerDefinitions.tl866a;
  static const tl866iiPlus = ProgrammerDefinitions.tl866iiPlus;
}

/// The catalog mask described by the pinned minipro INFOIC2PLUS source.
const int infoic2PlusModelMask = 0x70000000;

abstract final class ProgrammerDefinitions {
  static const tl866cs = ProgrammerDefinition(
    id: ProgrammerId.tl866cs,
    displayName: 'TL866CS',
    databaseTypes: {'INFOIC', 'LOGIC'},
    miniproModelName: 'tl866a',
    expectedHardwareModel: 'TL866CS',
    usbDeviceIds: {'04d8:e11c'},
    capabilities: {
      ProgrammerCapability.read,
      ProgrammerCapability.blankCheck,
      ProgrammerCapability.program,
      ProgrammerCapability.verify,
    },
    enabled: true,
  );

  static const tl866a = ProgrammerDefinition(
    id: ProgrammerId.tl866a,
    displayName: 'TL866A',
    databaseTypes: {'INFOIC', 'LOGIC'},
    miniproModelName: 'tl866a',
    expectedHardwareModel: 'TL866A',
    usbDeviceIds: {'04d8:e11c'},
    capabilities: {
      ProgrammerCapability.read,
      ProgrammerCapability.blankCheck,
      ProgrammerCapability.program,
      ProgrammerCapability.verify,
    },
    enabled: true,
  );

  static const tl866iiPlus = ProgrammerDefinition(
    id: ProgrammerId.tl866iiPlus,
    displayName: 'TL866II Plus',
    databaseTypes: {'INFOIC2PLUS', 'LOGIC'},
    miniproModelName: 'tl866ii',
    expectedHardwareModel: 'TL866II',
    usbDeviceIds: {'a466:0a53'},
    capabilities: {
      ProgrammerCapability.read,
      ProgrammerCapability.blankCheck,
      ProgrammerCapability.program,
      ProgrammerCapability.verify,
    },
    infoic2PlusPinMapBit: 0x20000000,
    enabled: true,
  );

  static const t48 = ProgrammerDefinition(
    id: ProgrammerId.t48,
    displayName: 'T48',
    databaseTypes: {'INFOIC2PLUS'},
    miniproModelName: 't48',
    expectedHardwareModel: 'T48',
    usbDeviceIds: {'a466:0a53'},
    capabilities: {},
    infoic2PlusPinMapBit: 0x40000000,
  );

  static const t56 = ProgrammerDefinition(
    id: ProgrammerId.t56,
    displayName: 'T56',
    databaseTypes: {'INFOIC2PLUS'},
    miniproModelName: 't56',
    expectedHardwareModel: 'T56',
    usbDeviceIds: {'a466:0a53'},
    capabilities: {},
    infoic2PlusPinMapBit: 0x10000000,
  );

  static const t76 = ProgrammerDefinition(
    id: ProgrammerId.t76,
    displayName: 'T76',
    databaseTypes: {'INFOICT76'},
    miniproModelName: 't76',
    expectedHardwareModel: 'T76',
    usbDeviceIds: {'a466:1a86'},
    capabilities: {},
  );

  static const all = [tl866cs, tl866a, tl866iiPlus, t48, t56, t76];
  static const enabled = [tl866cs, tl866a, tl866iiPlus];

  static ProgrammerDefinition? byId(ProgrammerId id) {
    for (final definition in all) {
      if (definition.id == id) return definition;
    }
    return null;
  }
}
