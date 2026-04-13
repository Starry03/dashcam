class DashcamStatus {
  const DashcamStatus({
    required this.isRecording,
    required this.elapsed,
    required this.storageUsedMb,
    required this.storageCapMb,
    required this.currentSegment,
    required this.lockedSegments,
    required this.lastError,
  });

  factory DashcamStatus.initial() {
    return const DashcamStatus(
      isRecording: false,
      elapsed: Duration.zero,
      storageUsedMb: 0,
      storageCapMb: 10240,
      currentSegment: 0,
      lockedSegments: 0,
      lastError: null,
    );
  }

  factory DashcamStatus.fromMap(Map<Object?, Object?> map) {
    return DashcamStatus(
      isRecording: map['isRecording'] as bool? ?? false,
      elapsed: Duration(seconds: map['elapsedSeconds'] as int? ?? 0),
      storageUsedMb: map['storageUsedMb'] as int? ?? 0,
      storageCapMb: map['storageCapMb'] as int? ?? 10240,
      currentSegment: map['currentSegment'] as int? ?? 0,
      lockedSegments: map['lockedSegments'] as int? ?? 0,
      lastError: map['lastError'] as String?,
    );
  }

  final bool isRecording;
  final Duration elapsed;
  final int storageUsedMb;
  final int storageCapMb;
  final int currentSegment;
  final int lockedSegments;
  final String? lastError;

  DashcamStatus copyWith({
    bool? isRecording,
    Duration? elapsed,
    int? storageUsedMb,
    int? storageCapMb,
    int? currentSegment,
    int? lockedSegments,
    String? lastError,
  }) {
    return DashcamStatus(
      isRecording: isRecording ?? this.isRecording,
      elapsed: elapsed ?? this.elapsed,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
      storageCapMb: storageCapMb ?? this.storageCapMb,
      currentSegment: currentSegment ?? this.currentSegment,
      lockedSegments: lockedSegments ?? this.lockedSegments,
      lastError: lastError,
    );
  }
}
