import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';

/// Voice message recorder widget - hold to record, release to send
class VoiceRecorderButton extends StatefulWidget {
  final Function(String audioPath) onRecordComplete;
  final bool isDark;
  final double size;

  const VoiceRecorderButton({
    super.key,
    required this.onRecordComplete,
    this.isDark = true,
    this.size = 48,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentPath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      debugPrint('VoiceRecorder: Has permission: $hasPermission');
      
      if (hasPermission) {
        String? path;
        RecordConfig config;
        
        if (kIsWeb) {
          // For web, use opus codec which is well-supported by browsers
          config = const RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: 128000,
            sampleRate: 48000,
          );
          // On web, path can be null - record returns blob URL
          path = null;
        } else {
          // For mobile, use AAC
          final directory = await getTemporaryDirectory();
          path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          config = const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          );
        }
        
        debugPrint('VoiceRecorder: Starting recording... path=$path, isWeb=$kIsWeb');
        await _recorder.start(config, path: path ?? '');
        debugPrint('VoiceRecorder: Recording started!');
        
        setState(() {
          _isRecording = true;
          _currentPath = path;
          _recordDuration = Duration.zero;
        });
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration += const Duration(seconds: 1);
          });
        });
      } else {
        debugPrint('VoiceRecorder: No permission');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Microphone permission required'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('VoiceRecorder: Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      debugPrint('VoiceRecorder: Stopping recording...');
      final path = await _recorder.stop();
      debugPrint('VoiceRecorder: Recording stopped, path: $path');
      
      setState(() {
        _isRecording = false;
      });
      
      if (path != null && path.isNotEmpty && _recordDuration.inSeconds >= 1) {
        debugPrint('VoiceRecorder: Recording complete, calling callback with path');
        widget.onRecordComplete(path);
      } else if (_recordDuration.inSeconds < 1) {
        // Too short - delete file (only on mobile)
        if (!kIsWeb && path != null && path.isNotEmpty) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hold longer to record'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      _recordDuration = Duration.zero;
    } catch (e) {
      debugPrint('VoiceRecorder: Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isRecording) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.5 + _pulseController.value * 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_recordDuration),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Using Listener for better web/mouse support (works with mouse down/up)
        Listener(
          onPointerDown: (_) => _startRecording(),
          onPointerUp: (_) => _stopRecording(),
          onPointerCancel: (_) => _stopRecording(),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isRecording ? widget.size * 1.2 : widget.size,
              height: _isRecording ? widget.size * 1.2 : widget.size,
              decoration: BoxDecoration(
                gradient: _isRecording
                    ? const LinearGradient(colors: [Colors.red, Colors.redAccent])
                    : (context.colors.brandGradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : (context.colors.accent))
                        .withOpacity(0.4),
                    blurRadius: _isRecording ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: _isRecording ? 28 : 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Voice message player widget - shows waveform and playback controls
class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final bool isDark;
  final Duration? duration;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    this.isDark = true,
    this.duration,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      debugPrint('VoicePlayer: Initializing with URL: ${widget.audioUrl}');
      
      _player.onDurationChanged.listen((d) {
        debugPrint('VoicePlayer: Duration changed: $d');
        if (mounted) setState(() => _duration = d);
      });
      
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      
      _player.onPlayerComplete.listen((_) {
        debugPrint('VoicePlayer: Playback complete');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
      
      _player.onPlayerStateChanged.listen((state) {
        debugPrint('VoicePlayer: State changed: $state');
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      });

      // Set the appropriate source based on URL type
      final url = widget.audioUrl;
      Source source;
      
      if (url.startsWith('blob:') || url.startsWith('data:')) {
        // Web blob URL or data URL
        debugPrint('VoicePlayer: Using UrlSource for blob/data URL');
        source = UrlSource(url);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        // Remote URL from backend
        debugPrint('VoicePlayer: Using UrlSource for HTTP URL');
        source = UrlSource(url);
      } else if (!kIsWeb && (url.startsWith('/') || url.contains('://'))) {
        // Local file path on mobile
        debugPrint('VoicePlayer: Using DeviceFileSource for local file');
        source = DeviceFileSource(url);
      } else {
        // Default to URL source
        debugPrint('VoicePlayer: Using UrlSource as default');
        source = UrlSource(url);
      }
      
      await _player.setSource(source);
      debugPrint('VoicePlayer: Source set successfully');
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('VoicePlayer: Error initializing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        debugPrint('VoicePlayer: Playing/resuming audio');
        // Just resume - source is already set
        await _player.resume();
      }
    } catch (e) {
      debugPrint('VoicePlayer: Error playing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.05)
            : ElegantColors.cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _isLoading ? null : _togglePlay,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: context.colors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : _error != null
                      ? const Icon(Icons.error_outline, color: Colors.red, size: 24)
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Waveform / Progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Simple waveform visualization
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(20, (i) {
                      final isBeforeProgress = i / 20 < progress;
                      final barHeight = 8.0 + (i % 5) * 3.0 + (i % 3) * 2.0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 3,
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isBeforeProgress
                              ? (context.colors.accent)
                              : (widget.isDark ? Colors.white24 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                
                // Duration
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
