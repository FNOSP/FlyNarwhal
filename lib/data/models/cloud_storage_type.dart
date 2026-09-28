/// Cloud storage provider of a netdisk-backed media stream.
///
/// Values and member names mirror the web player's `cloud_storage_type` enum
/// so this file can be diffed against the web bundle directly.
enum CloudStorageType {
  baiduPan(1, '百度网盘'),
  aliPan(2, '阿里云盘'),
  oneOneFivePan(3, '115 生活'),
  quarkPan(4, '夸克网盘'),
  oneTwoThreePan(5, '123 云盘'),
  oneDrivePan(6, 'Microsoft OneDrive'),
  googleDrivePan(7, 'Google Drive'),
  dropboxPan(8, 'Dropbox'),
  oneDriveBusiness(9, 'Microsoft OneDrive for Business'),
  oneDrivePersonal(10, 'Microsoft OneDrive'),

  /// Not a cloud drive: the NAS resolves the `.strm` content into a playable
  /// URL itself, so the stream has no netdisk backend behind it.
  strm(9001, 'STRM'),

  /// Any value the backend reports that this build does not know about.
  unknown(-1, '');

  const CloudStorageType(this.value, this.displayLabel);

  final int value;
  final String displayLabel;

  static final Map<int, CloudStorageType> _byValue = {
    for (final type in values)
      if (type != unknown) type.value: type,
  };

  /// Resolves a raw `cloud_storage_type` from the API.
  ///
  /// Unknown values map to [unknown] rather than throwing: the backend adds
  /// providers over time, and an unrecognized one must not break playback.
  static CloudStorageType fromValue(int? value) {
    if (value == null) return unknown;
    return _byValue[value] ?? unknown;
  }

  /// Whether the backend reported a provider this build recognizes.
  bool get isKnown => this != unknown;

  bool get isBaiduPan => this == baiduPan;
  bool get isAliPan => this == aliPan;
  bool get isOneOneFivePan => this == oneOneFivePan;
  bool get isQuarkPan => this == quarkPan;
  bool get isOneTwoThreePan => this == oneTwoThreePan;
  bool get isStrm => this == strm;
}