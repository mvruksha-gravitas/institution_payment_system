import 'package:flutter/material.dart';


class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _homeKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _contactKey = GlobalKey();
  final _scroll = ScrollController();

  static const String _appUrl = 'https://iafncwlll3ts3frhzh3z.share.dreamflow.app/';

  Future<void> _openApp() async {
    if (!mounted) return;
    try {
      Navigator.of(context).pushNamed('/login');
    } catch (_) {}
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartStay PG Manager'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).colorScheme.primary,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        actions: [
          TextButton(onPressed: _openApp, child: const Text('Launch App', style: TextStyle(color: Colors.white)))
        ],
      ),

      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Hero Section
          Container(
            key: _homeKey,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: LayoutBuilder(builder: (ctx, c) {
                final isNarrow = c.maxWidth < 900;
                final imageUrl = 'https://pixabay.com/get/g78ebaffb50595f0b61db0f5bbfebaeee6c535b0fa031c62b8a473c3ae7bd4f1cb6f5375048b743ef6d08b67d4b1086341bdf1eaeef8db9ab74a4d85c8d487de0_1280.jpg';
                return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Simplify Your PG Management', style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Manage rooms, tenants, and payments seamlessly in one platform.', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95))),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(onPressed: _openApp, icon: const Icon(Icons.open_in_new), label: const Text('Launch Application'), style: FilledButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white)),
                      OutlinedButton.icon(onPressed: () => _scrollTo(_contactKey), icon: const Icon(Icons.calendar_month, color: Colors.white), label: const Text('Request Demo'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)))
                    ]),
                    const SizedBox(height: 12),
                    Text('Trusted by PG owners across India to run their accommodations smoothly.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)))
                  ])),
                  if (!isNarrow) const SizedBox(width: 24),
                  if (!isNarrow) Expanded(child: AspectRatio(aspectRatio: 16/10, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(imageUrl, fit: BoxFit.cover))))
                ]);
              }),
            ),
          ),

          // Features
          Container(
            key: _featuresKey,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Key Features', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (ctx, c) {
                final w = c.maxWidth;
                final cross = w >= 1100 ? 3 : (w >= 800 ? 3 : 1);
                final items = _features;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 3.2),
                  itemBuilder: (ctx, i) => _FeatureCard(data: items[i]),
                );
              })
            ]),
          ),

          // How it works
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('How It Works', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (ctx, c) {
                final w = c.maxWidth;
                final isNarrow = w < 900;
                final steps = [
                  _Step(icon: Icons.apartment, title: 'Add Your PG', desc: 'Setup rooms and categories.'),
                  _Step(icon: Icons.person_add, title: 'Add Tenants', desc: 'Assign beds and record details.'),
                  _Step(icon: Icons.payments, title: 'Track Payments', desc: 'Monitor rents and reminders.'),
                ];
                return isNarrow
                    ? Column(children: steps.map((s) => _StepTile(step: s)).toList())
                    : Row(children: steps.map((s) => Expanded(child: _StepTile(step: s))).toList());
              })
            ]),
          ),

          // Pricing
          Container(
            key: _pricingKey,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Simple Pricing', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (ctx, c) {
                final w = c.maxWidth; final isNarrow = w < 900;
                final plans = _plans;
                return isNarrow
                    ? Column(children: plans.map((p) => _PriceCard(data: p, onStart: _openApp)).toList())
                    : Row(children: plans.map((p) => Expanded(child: _PriceCard(data: p, onStart: _openApp))).toList());
              })
            ]),
          ),

          // Testimonials
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Trusted by PG Owners', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (ctx, c) {
                final w = c.maxWidth; final isNarrow = w < 900;
                return isNarrow
                    ? Column(children: _testimonials.map((t) => _TestimonialCard(data: t)).toList())
                    : Row(children: _testimonials.map((t) => Expanded(child: _TestimonialCard(data: t))).toList());
              })
            ]),
          ),

          // Contact
          Container(
            key: _contactKey,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Request a Demo', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _ContactForm(onSubmit: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you! We\'ll reach out soon.')));
                      }),
                    ),
                  ),
                ),
              )
            ]),
          ),

        ]),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: InkWell(onTap: onTap, child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white))));
  }
}

class _FeatureCard extends StatelessWidget {
  final Map<String, dynamic> data; const _FeatureCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        CircleAvatar(radius: 20, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), child: Icon(data['icon'] as IconData, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(data['title'] as String, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(data['desc'] as String, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)
        ]))
      ])),
    );
  }
}

class _Step { final IconData icon; final String title; final String desc; const _Step({required this.icon, required this.title, required this.desc}); }
class _StepTile extends StatelessWidget { final _Step step; const _StepTile({required this.step}); @override Widget build(BuildContext context) { return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [CircleAvatar(radius: 20, backgroundColor: Colors.blue.withValues(alpha: 0.12), child: Icon(step.icon, color: Colors.blue)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(step.title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4), Text(step.desc, style: Theme.of(context).textTheme.bodySmall)]) )]))); } }

class _PriceCard extends StatelessWidget {
  final Map<String, dynamic> data; final VoidCallback onStart; const _PriceCard({required this.data, required this.onStart});
  @override
  Widget build(BuildContext context) {
    final isPopular = (data['popular'] as bool?) ?? false;
    final color = isPopular ? Theme.of(context).colorScheme.primary : Colors.blueGrey;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(data['title'] as String, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(width: 8),
            if (isPopular) Chip(label: const Text('Most Popular'), backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10))
          ]),
          const SizedBox(height: 6),
          Text(data['subtitle'] as String, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: (data['features'] as List<String>).map((f) => Chip(label: Text(f), avatar: const Icon(Icons.check, size: 16, color: Colors.green), backgroundColor: Colors.green.withValues(alpha: 0.08))).toList()),
          const Spacer(),
          Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: onStart, icon: const Icon(Icons.rocket_launch), label: const Text('Get Started'), style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white)))
        ]),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final Map<String, String> data; const _TestimonialCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final image = data['image']!;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(image, width: 96, height: 64, fit: BoxFit.cover)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('"${data['quote']}"', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text('– ${data['author']}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700))
      ]))
    ])));
  }
}

class _ContactForm extends StatefulWidget { final VoidCallback onSubmit; const _ContactForm({required this.onSubmit}); @override State<_ContactForm> createState() => _ContactFormState(); }
class _ContactFormState extends State<_ContactForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  @override
  void dispose() { _name.dispose(); _email.dispose(); _message.dispose(); super.dispose(); }
  Future<void> _submit() async {
    final name = _name.text.trim(); final email = _email.text.trim(); final msg = _message.text.trim();
    if (name.isEmpty || email.isEmpty || msg.isEmpty) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return; setState(() => _sending = false);
    widget.onSubmit();
    _name.clear(); _email.clear(); _message.clear();
  }
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress)),
      ]),
      const SizedBox(height: 8),
      TextField(controller: _message, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()), minLines: 4, maxLines: 6),
      const SizedBox(height: 12),
      Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _sending ? null : _submit, icon: const Icon(Icons.send), label: _sending ? const Text('Sending...') : const Text('Submit')))
    ]);
  }
}

class _FooterLink extends StatelessWidget { final String label; const _FooterLink({required this.label}); @override Widget build(BuildContext context) { return InkWell(onTap: () {}, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Text(label, style: Theme.of(context).textTheme.bodySmall))); }}

final List<Map<String, dynamic>> _features = [
  {'icon': Icons.meeting_room, 'title': 'Room & Bed Management', 'desc': 'Organize rooms by category and assign custom bed numbers.'},
  {'icon': Icons.badge, 'title': 'Tenant Profiles', 'desc': 'Store tenant details, assign rooms, and track stay duration.'},
  {'icon': Icons.request_quote, 'title': 'Easy Payment Tracking', 'desc': 'Record rent payments, send reminders, and view balances.'},
  {'icon': Icons.show_chart, 'title': 'Reports & Analytics', 'desc': 'Insights into occupancy, revenue, and history.'},
  {'icon': Icons.event_available, 'title': 'Bookings & Availability', 'desc': 'Check free rooms/beds and onboard tenants.'},
  {'icon': Icons.smartphone, 'title': 'Mobile-Friendly Access', 'desc': 'Manage your PG anytime, anywhere.'},
];

final List<Map<String, dynamic>> _plans = [
  {'title': 'Free Plan', 'subtitle': 'Basic features for small PGs', 'popular': false, 'features': ['Up to 20 tenants', 'Room & Bed', 'Basic payments']},
  {'title': 'Pro Plan', 'subtitle': 'Unlimited tenants, analytics, all features', 'popular': true, 'features': ['Unlimited tenants', 'Advanced analytics', 'Exports & PDF']},
  {'title': 'Enterprise', 'subtitle': 'Custom for PG networks/hostels', 'popular': false, 'features': ['Dedicated support', 'Custom integrations', 'SLA']},
];

final List<Map<String, String>> _testimonials = [
  {'quote': 'This app made managing my PG effortless!', 'author': 'Ramesh, PG Owner', 'image': 'https://pixabay.com/get/gc1c9b06afad2b6f7cfe6fd851d3b349bd900a4cecb104a99be8f587fe1058b40d2ca92c2f832d4e71690877c36f1b5bde38c2029f8b928846329a582dcbf43cd_1280.jpg'},
  {'quote': 'Simple, fast, and reliable. My tenants also find it very easy to use.', 'author': 'Anjali, Tenant', 'image': 'https://pixabay.com/get/ge9d10a76999bc8726bd4f8392e150eacdf996fdf274641d02e0cc99ab527a7b0ab81c719f5f16719fc7534b6f5254da92995712af2f8d97d004d676c3cf0daa2_1280.jpg'},
];
