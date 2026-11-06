import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:voltkit_rtc/voltkit_rtc.dart';

/// Someone else's camera. Tells the SDK how big it is drawn, so this view receives the copy that fits and nothing more.
class RemoteVideo extends StatefulWidget {
  const RemoteVideo({super.key, required this.client, required this.track});

  final StreamClient client;
  final RemoteTrack track;

  @override
  State<RemoteVideo> createState() => _RemoteVideoState();
}

class _RemoteVideoState extends State<RemoteVideo> {
  final _renderer = RTCVideoRenderer();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.track.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(RemoteVideo old) {
    super.didUpdateWidget(old);
    if (old.track.producerId != widget.track.producerId) {
      old.client.clearVideoView(old.track.producerId);
      if (_ready) _renderer.srcObject = widget.track.stream;
    }
  }

  @override
  void dispose() {
    widget.client.clearVideoView(widget.track.producerId);
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, box) {
        widget.client.setVideoView(
          widget.track.producerId,
          width: box.maxWidth,
          height: box.maxHeight,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        return RepaintBoundary(
          child: RTCVideoView(_renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
        );
      },
    );
  }
}

/// Your own camera.
class LocalVideo extends StatefulWidget {
  const LocalVideo({super.key, required this.stream, required this.mirror});

  final MediaStream stream;
  final bool mirror;

  @override
  State<LocalVideo> createState() => _LocalVideoState();
}

class _LocalVideoState extends State<LocalVideo> {
  final _renderer = RTCVideoRenderer();
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    await _renderer.initialize();
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(LocalVideo old) {
    super.didUpdateWidget(old);
    if (_ready && old.stream.id != widget.stream.id) _renderer.srcObject = widget.stream;
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.expand();
    return RepaintBoundary(
      child: RTCVideoView(_renderer, mirror: widget.mirror, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
    );
  }
}
