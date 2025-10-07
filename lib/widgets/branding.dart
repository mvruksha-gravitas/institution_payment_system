import 'package:flutter/material.dart';

class BrandedLogo extends StatelessWidget {
  final double? height;
  final Color? color;
  
  const BrandedLogo({super.key, this.height, this.color});
  
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mvruksha_logo.png',
      height: height ?? 32,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      errorBuilder: (context, error, stackTrace) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business, size: (height ?? 32) * 0.8, color: color),
            SizedBox(width: 8),
            Text(
              'mVruksha',
              style: TextStyle(
                fontSize: (height ?? 32) * 0.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}

class BrandedHeaderLine extends StatelessWidget {
  const BrandedHeaderLine({super.key});
  @override
  Widget build(BuildContext context) {
    final onAppBar = Theme.of(context).appBarTheme.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final title = Theme.of(context).textTheme.labelSmall?.copyWith(color: onAppBar.withValues(alpha: 0.95), fontWeight: FontWeight.w700);
    final sub = Theme.of(context).textTheme.labelSmall?.copyWith(color: onAppBar.withValues(alpha: 0.7), fontWeight: FontWeight.w500, fontSize: 10);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandedLogo(height: 16, color: onAppBar.withValues(alpha: 0.8)),
        SizedBox(width: 8),
        Flexible(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PG Book', style: title, overflow: TextOverflow.ellipsis),
            Text('by mVruksha Softwares', style: sub, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ],
    );
  }
}

class BrandedFooter extends StatelessWidget {
  final EdgeInsets padding;
  const BrandedFooter({super.key, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12)});
  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandedLogo(height: 24, color: onSurface.withValues(alpha: 0.6)),
              SizedBox(height: 8),
              Text(
                'PGPe — A product of mVruksha Softwares',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.75),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
