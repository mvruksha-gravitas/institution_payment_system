import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:institutation_payment_system/widgets/branding.dart';

class PortalHubPage extends StatefulWidget {
  const PortalHubPage({super.key});
  @override
  State<PortalHubPage> createState() => _PortalHubPageState();
}

class _PortalHubPageState extends State<PortalHubPage> {
  final TextEditingController _instIdCtrl = TextEditingController();

  Uri _studentRegistrationUri(String instId) {
    final base = Uri.base;
    final origin = base.hasAuthority ? '${base.scheme}://${base.authority}' : '';
    // Route to unified registration with role=student and inst parameter
    final path = '/register';
    final uri = Uri.parse('$origin$path').replace(queryParameters: {'role': 'student', 'inst': instId});
    return uri;
  }

  String _qrUrlFor(Uri url) => 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(url.toString())}';

  Future<void> _copyToClipboard(String text) async {
    // Avoid extra dependencies; show a dialog with selectable text for copy
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Copy link'),
        content: SelectableText(text),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _openHome() async { if (!mounted) return; Navigator.of(context).pushNamed('/'); }

  @override
  void dispose() {
    _instIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(

      appBar: AppBar(
        title: const BrandedHeaderLine(),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.primary,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        ),
        actions: [TextButton(onPressed: _openHome, child: const Text('Website', style: TextStyle(color: Colors.white)))],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  BrandedLogo(height: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Portal', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text('Powered by mVruksha Softwares', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Access registration and login directly from the website. Share a student registration link or QR with your students for quick onboarding.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (ctx, c) {
                final w = c.maxWidth;
                final cross = w >= 1000 ? 3 : (w >= 700 ? 2 : 1);
                final items = [
                  _HubItem(icon: Icons.how_to_reg, title: 'Institution Registration', desc: 'Enroll your PG for approval.', onTap: () => Navigator.of(context).pushNamed('/register')),
                  _HubItem(icon: Icons.person_add_alt_1, title: 'Student Registration', desc: 'Register as a student with InstId.', onTap: () => Navigator.of(context).pushNamed('/register', arguments: {'role': 'student'})),
                  _HubItem(icon: Icons.apartment, title: 'Institution Admin Login', desc: 'Sign in to manage rooms, tenants, and fees.', onTap: () => Navigator.of(context).pushNamed('/login')),
                  _HubItem(icon: Icons.school, title: 'Student Login', desc: 'Sign in to view dues, receipts, and updates.', onTap: () => Navigator.of(context).pushNamed('/login')),
                  _HubItem(icon: Icons.admin_panel_settings, title: 'Super Admin Login', desc: 'Approve institutions and oversee operations.', onTap: () => Navigator.of(context).pushNamed('/admin-login')),
                ];
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.6),
                  itemBuilder: (_, i) => _HubCard(item: items[i]),
                );
              }),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.qr_code, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Share Student Registration Link & QR', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Enter your InstId to generate a shareable link and QR code. Students can scan or click to open the form directly.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: _instIdCtrl, decoration: InputDecoration(labelText: 'InstId', prefixIcon: Icon(Icons.badge, color: Theme.of(context).colorScheme.primary), border: const OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      FilledButton.icon(onPressed: () { setState(() {}); }, icon: const Icon(Icons.link), label: const Text('Generate')),
                    ]),
                    const SizedBox(height: 12),
                    if (_instIdCtrl.text.trim().isNotEmpty) ...[
                      Builder(builder: (context) {
                        final url = _studentRegistrationUri(_instIdCtrl.text.trim());
                        final qr = _qrUrlFor(url);
                        return LayoutBuilder(builder: (ctx, c) {
                          final isNarrow = c.maxWidth < 700;
                          return isNarrow
                              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _LinkRow(url: url, onCopy: () => _copyToClipboard(url.toString())),
                                  const SizedBox(height: 12),
                                  Center(child: Image.network(qr, width: 220, height: 220, fit: BoxFit.contain)),
                                ])
                              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: _LinkRow(url: url, onCopy: () => _copyToClipboard(url.toString()))),
                                  const SizedBox(width: 16),
                                  Image.network(qr, width: 220, height: 220, fit: BoxFit.contain),
                                ]);
                        });
                      })
                    ]
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _openHome, icon: const Icon(Icons.home, color: Colors.blue), label: const Text('Back to Website')))
            ]),
          ),
        ),
      ),
    );
  }
}

class _HubItem {
  final IconData icon; final String title; final String desc; final VoidCallback onTap;
  _HubItem({required this.icon, required this.title, required this.desc, required this.onTap});
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  const _HubCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), child: Icon(item.icon, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(item.desc, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary)
          ]),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final Uri url; final VoidCallback onCopy;
  const _LinkRow({required this.url, required this.onCopy});
  Future<void> _open(Uri url) async { try { await launchUrl(url, webOnlyWindowName: '_blank'); } catch (_) {} }
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Shareable link', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(8)),
        child: SelectableText(url.toString(), style: Theme.of(context).textTheme.bodySmall),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => _open(url), icon: const Icon(Icons.open_in_new), label: const Text('Open')),
        OutlinedButton.icon(onPressed: onCopy, icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary), label: const Text('Copy')),
      ])
    ]);
  }
}
