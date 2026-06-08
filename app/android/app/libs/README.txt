Download the FFmpegKit AAR and place it here:

1. Download `ffmpeg-kit-full-gpl-6.0-2.aar` from the official FFmpegKit releases or build it following FFmpegKit docs.
2. Put the file at `app/android/app/libs/ffmpeg-kit-full-gpl-6.0-2.aar`.

When present, the Gradle build will use the local AAR as a fallback and skip fetching from remote repositories.

Note about licensing: the `-full-gpl` artifact is GPL-licensed. If you need a different license, use a different FFmpegKit variant.
