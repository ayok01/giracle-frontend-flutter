import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// A CachedNetworkImage variant that attaches the Giracle session cookie
/// so authenticated endpoints (`/user/icon/*`, `/message/file/*`,
/// `/server/custom-emoji/*`) return the image bytes instead of 401.
class AuthedNetworkImage extends ConsumerStatefulWidget {
  const AuthedNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext)? placeholder;
  final Widget Function(BuildContext, Object)? errorWidget;

  @override
  ConsumerState<AuthedNetworkImage> createState() => _AuthedNetworkImageState();
}

class _AuthedNetworkImageState extends ConsumerState<AuthedNetworkImage> {
  Map<String, String>? _headers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void didUpdateWidget(covariant AuthedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    final cookie = await ref.read(apiClientProvider).cookieHeader(widget.url);
    if (!mounted) return;
    setState(() {
      _headers = cookie.isEmpty ? null : {'Cookie': cookie};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder?.call(context) ??
            const Center(
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      );
    }
    return CachedNetworkImage(
      imageUrl: widget.url,
      httpHeaders: _headers,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder == null
          ? null
          : (ctx, _) => widget.placeholder!(ctx),
      errorWidget: (ctx, _, err) =>
          widget.errorWidget?.call(ctx, err) ??
          const Icon(Icons.broken_image),
    );
  }
}

/// Circular avatar version — wraps `AuthedNetworkImage` in a ClipOval.
class AuthedAvatar extends StatelessWidget {
  const AuthedAvatar({
    super.key,
    required this.url,
    this.radius = 20,
    this.fallback,
  });

  final String url;
  final double radius;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AuthedNetworkImage(
          url: url,
          fit: BoxFit.cover,
          errorWidget: (_, __) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: fallback ?? const Icon(Icons.person),
          ),
        ),
      ),
    );
  }
}
