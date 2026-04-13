class RecordingConfig {
  const RecordingConfig({
    this.segmentDurationMinutes = 5,
    this.maxStorageGb = 10,
    this.videoWidth = 1920,
    this.videoHeight = 1080,
    this.videoFps = 30,
  });

  final int segmentDurationMinutes;
  final int maxStorageGb;
  final int videoWidth;
  final int videoHeight;
  final int videoFps;

  Map<String, Object> toMap() {
    return {
      'segmentDurationMinutes': segmentDurationMinutes,
      'maxStorageGb': maxStorageGb,
      'videoWidth': videoWidth,
      'videoHeight': videoHeight,
      'videoFps': videoFps,
    };
  }
}
