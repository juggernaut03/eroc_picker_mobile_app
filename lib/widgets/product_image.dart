import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Cached product image with disk caching, memory caching, and a fallback widget.
///
/// - Caches to disk so repeat views are instant.
/// - Limits in-memory decode to the displayed size (saves RAM in long lists).
/// - Dedupes parallel fetches for the same URL.
class ProductImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const ProductImage({
    super.key,
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return fallback;

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final memW = width != null ? (width! * dpr).round() : null;
    final memH = height != null ? (height! * dpr).round() : null;

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (ctx, _) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF4F3FA),
        child: const Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCBD5E1)),
          ),
        ),
      ),
      errorWidget: (ctx, url, err) => fallback,
    );
  }
}
