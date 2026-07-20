import 'package:flutter/material.dart';

/// The home room's camera: a scale + focal alignment the page animates.
/// Identity is `scale == 1` — the lens then paints its child untouched, so
/// goldens, standalone hosts, and reduced motion are byte-identical.
class RoomCamera extends ChangeNotifier {
  double _scale = 1.0;
  Alignment _focal = Alignment.center;

  double get scale => _scale;
  Alignment get focal => _focal;

  void set(double scale, Alignment focal) {
    if (scale == _scale && focal == _focal) return;
    _scale = scale;
    _focal = focal;
    notifyListeners();
  }

  void reset() => set(1.0, _focal);
}

/// Scales the room's **rendered raster layer** around [RoomCamera.focal] — a
/// photographic camera move (the compositor samples the already-painted
/// layer), never a geometry re-render of crisp sprites at fractional scale
/// (the pixel-shimmer doctrine). The [RepaintBoundary] is what makes the
/// child a layer; [FilterQuality.low] gives the deliberate soft "camera"
/// sampling in motion. At `scale <= 1` the child renders with no transform
/// at all.
class RoomZoomLens extends StatelessWidget {
  const RoomZoomLens({super.key, required this.camera, required this.child});

  final RoomCamera camera;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inner = RepaintBoundary(child: child);
    return ListenableBuilder(
      listenable: camera,
      child: inner,
      builder: (context, c) {
        if (camera.scale <= 1.0) return c!;
        return ClipRect(
          child: Transform.scale(
            key: const ValueKey('room_camera_zoom'),
            scale: camera.scale,
            alignment: camera.focal,
            filterQuality: FilterQuality.low,
            child: c,
          ),
        );
      },
    );
  }
}
