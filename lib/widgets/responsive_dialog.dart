import 'package:flutter/material.dart';

/// A responsive dialog that adapts to small screens by presenting a fullscreen dialog
/// with an AppBar and a bottom action bar. On larger screens it falls back to AlertDialog.
class AppResponsiveDialog extends StatelessWidget {
  final String? titleText;
  final Widget? titleWidget;
  final Widget content;
  final List<Widget>? actions;
  final List<Widget>? headerActions; // shown in the AppBar for fullscreen variant
  final EdgeInsetsGeometry? contentPadding;
  final double maxWidth;
  final double maxHeightFactor; // 0-1.0 of screen height for non-fullscreen variant

  const AppResponsiveDialog({super.key, this.titleText, this.titleWidget, required this.content, this.actions, this.headerActions, this.contentPadding, this.maxWidth = 720, this.maxHeightFactor = 0.85});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600 || size.height < 540;

    if (isCompact) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: titleWidget ?? (titleText != null ? Text(titleText!) : const Text('Details')), actions: headerActions),
          body: SafeArea(child: Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: content))),
          bottomNavigationBar: actions == null || actions!.isEmpty
              ? null
              : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: _ActionRow(children: actions!))),
        ),
      );
    }

    final dialogContent = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: size.height * maxHeightFactor),
      child: SingleChildScrollView(padding: const EdgeInsets.only(top: 8), child: content),
    );

    return AlertDialog(
      title: titleWidget ?? (titleText != null ? Text(titleText!, overflow: TextOverflow.ellipsis) : null),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(24, 0, 24, 16),
      content: dialogContent,
      actions: actions,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final List<Widget> children;
  const _ActionRow({required this.children});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: _spaced(children));
  }

  List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(const SizedBox(width: 12));
    }
    return out;
  }
}
