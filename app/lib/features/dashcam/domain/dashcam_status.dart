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
  );
}
