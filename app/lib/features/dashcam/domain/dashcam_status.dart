class DashcamStatus {
  const DashcamStatus({
    required this.isRecording,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.storageUsedMb,
    required this.freeStorageMb,
    required this.lastSegment,
    required this.lastSegmentLocked,
    required this.warning,
    required this.isFrontCamera,
    this.speedKmh = 0.0,
    this.infinityFocus = true,
  });

  final bool isRecording;
  final bool isPaused;
  final int elapsedSeconds;
  final int storageUsedMb;
  final int freeStorageMb;
  final String lastSegment;
  final bool lastSegmentLocked;
  final String warning;
  final bool isFrontCamera;
  final double speedKmh;
  final bool infinityFocus;

  factory DashcamStatus.fromMap(Map<Object?, Object?> map) {
    return DashcamStatus(
      isRecording: map['isRecording'] as bool? ?? false,
      isPaused: map['isPaused'] as bool? ?? false,
      elapsedSeconds: map['elapsedSeconds'] as int? ?? 0,
      storageUsedMb: map['storageUsedMb'] as int? ?? 0,
      freeStorageMb: map['freeStorageMb'] as int? ?? 0,
      lastSegment: map['lastSegment'] as String? ?? '-',
      lastSegmentLocked: map['lastSegmentLocked'] as bool? ?? false,
      warning: map['warning'] as String? ?? '',
      isFrontCamera: map['isFrontCamera'] as bool? ?? false,
      speedKmh: (map['speedKmh'] as num?)?.toDouble() ?? 0.0,
      infinityFocus: map['infinityFocus'] as bool? ?? true,
    );
  }

  static const idle = DashcamStatus(
    isRecording: false,
    isPaused: false,
    elapsedSeconds: 0,
    storageUsedMb: 0,
    freeStorageMb: 0,
    lastSegment: '-',
    lastSegmentLocked: false,
    warning: '',
    isFrontCamera: false,
    speedKmh: 0.0,
    infinityFocus: true,
  );
}
