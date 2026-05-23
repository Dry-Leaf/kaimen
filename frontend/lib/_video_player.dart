import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DesktopFriendlyVideoPlayer extends StatefulWidget {
  final String videoPath;

  const DesktopFriendlyVideoPlayer({super.key, required this.videoPath});

  @override
  State<DesktopFriendlyVideoPlayer> createState() =>
      _DesktopFriendlyVideoPlayerState();
}

class _DesktopFriendlyVideoPlayerState
    extends State<DesktopFriendlyVideoPlayer> {
  VideoPlayerController? _currentController;
  VideoPlayerController? _oldController;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer(widget.videoPath);
  }

  void _initializePlayer(String path) {
    _oldController = _currentController;
    _isInitialized = false;

    final nextController = VideoPlayerController.file(File(path));

    nextController
        .initialize()
        .then((_) {
          if (!mounted) {
            nextController.dispose();
            return;
          }

          if (widget.videoPath == path) {
            nextController.setLooping(true);

            setState(() {
              _currentController = nextController;
              _isInitialized = true;
              _currentController!.setVolume(0.0);
              _currentController!.pause();
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _oldController?.dispose();
              _oldController = null;
            });
          } else {
            nextController.dispose();
          }
        })
        .catchError((error) {
          debugPrint("Error initializing video path: $error");
          if (mounted) {
            setState(() {
              _oldController?.dispose();
              _oldController = null;
            });
          }
        });
  }

  @override
  void didUpdateWidget(covariant DesktopFriendlyVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger seamless swap only if the incoming file path changed
    if (oldWidget.videoPath != widget.videoPath) {
      _hideTimer?.cancel();
      _initializePlayer(widget.videoPath);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _currentController?.dispose();
    _oldController?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_currentController == null || !_isInitialized) return;
    setState(() {
      if (_currentController!.value.isPlaying) {
        _currentController!.pause();
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _currentController!.play();
        _startHideTimer();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_currentController != null && _currentController!.value.isPlaying) {
      _hideTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _currentController!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _revealControls() {
    setState(() => _showControls = true);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio from whichever controller is currently valid
    final activeRatio =
        _currentController?.value.aspectRatio ??
        _oldController?.value.aspectRatio ??
        1.0;

    return SizedBox(
      height: 335,
      width: 335,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AspectRatio(
          aspectRatio: activeRatio,
          child: MouseRegion(
            onHover: (_) => _revealControls(),
            onEnter: (_) => _revealControls(),
            child: Container(
              color: Colors.black87,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Holds previous video's terminal frame alive
                  if (_oldController != null &&
                      _oldController!.value.isInitialized)
                    VideoPlayer(_oldController!),

                  // Layer 2: Instantly covers Layer 1 once the new frame is fully baked
                  if (_currentController != null && _isInitialized)
                    GestureDetector(
                      onTap: _togglePlayback,
                      child: VideoPlayer(_currentController!),
                    ),

                  // Optional indicator: Only reveals if there is no image cache payload whatsoever
                  if (!_isInitialized && _oldController == null)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
                      ),
                    ),

                  // Layer 3: Play/Pause interactive overlay icon layer
                  AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: GestureDetector(
                        onTap: _togglePlayback,
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          radius: 28,
                          child: Icon(
                            (_currentController?.value.isPlaying ?? false)
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
