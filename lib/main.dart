import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:institutation_payment_system/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:institutation_payment_system/pages/unified_login_page.dart';
import 'package:institutation_payment_system/pages/admin_login_page.dart';
import 'package:institutation_payment_system/pages/unified_registration_page.dart';
import 'package:institutation_payment_system/pages/portal_hub_page.dart';
import 'package:institutation_payment_system/pages/admin_portal_page.dart';
import 'package:institutation_payment_system/pages/institution_admin_portal_page.dart';
import 'package:institutation_payment_system/pages/student_portal_page.dart';
import 'package:institutation_payment_system/state/app_state.dart';
import 'package:institutation_payment_system/firebase_options.dart';
import 'package:institutation_payment_system/widgets/branding.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ChangeNotifierProvider(create: (_) => AppState()..load(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PG Book',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      scrollBehavior: const AppScrollBehavior(),
      builder: (context, child) => child ?? const SizedBox.shrink(),
      routes: {
        '/': (context) => const AppHomePage(),
        '/portal': (context) => const PortalHubPage(),
        '/register': (context) => const UnifiedRegistrationPage(),
        '/login': (context) => const UnifiedLoginPage(),
        '/admin-login': (context) => const AdminLoginPage(),
        '/admin': (context) => const AdminPortalPage(),
        '/institution-admin': (context) => const InstitutionAdminPortalPage(),
        '/student': (context) => const StudentPortalPage(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '/';
        final basePath = Uri.parse(name).path;
        switch (basePath) {
          case '/':
            return MaterialPageRoute(builder: (_) => const AppHomePage(), settings: settings);
          case '/portal':
            return MaterialPageRoute(builder: (_) => const PortalHubPage(), settings: settings);
          case '/register':
            return MaterialPageRoute(builder: (_) => const UnifiedRegistrationPage(), settings: settings);
          case '/login':
            return MaterialPageRoute(builder: (_) => const UnifiedLoginPage(), settings: settings);
          case '/admin-login':
            return MaterialPageRoute(builder: (_) => const AdminLoginPage(), settings: settings);
          case '/admin':
            return MaterialPageRoute(builder: (_) => const AdminPortalPage(), settings: settings);
          case '/institution-admin':
            return MaterialPageRoute(builder: (_) => const InstitutionAdminPortalPage(), settings: settings);
          case '/student':
            return MaterialPageRoute(builder: (_) => const StudentPortalPage(), settings: settings);
          default:
            return null;
        }
      },
      initialRoute: '/',
    );
  }
}

class AppHomePage extends StatefulWidget {
  const AppHomePage({super.key});
  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  final _homeKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _contactKey = GlobalKey();
  Future<void> _openApp() async {
    if (!mounted) return;
    try {
      Navigator.of(context).pushNamed('/portal');
    } catch (_) {}
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.1);
  }

  Widget _buildDesktopNav() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavButton(label: 'Home', onTap: () => _scrollTo(_homeKey)),
        _NavButton(label: 'Features', onTap: () => _scrollTo(_featuresKey)),
        _NavButton(label: 'Pricing', onTap: () => _scrollTo(_pricingKey)),
        _NavButton(label: 'Portal', onTap: () => Navigator.of(context).pushNamed('/portal')),
        _NavButton(label: 'Contact', onTap: () => _scrollTo(_contactKey)),
      ],
    );
  }

  PopupMenuButton<String> _navMenu(ThemeData theme) => PopupMenuButton<String>(
        tooltip: 'Navigate',
        onSelected: (value) {
          switch (value) {
            case 'home':
              _scrollTo(_homeKey); break;
            case 'features':
              _scrollTo(_featuresKey); break;
            case 'pricing':
              _scrollTo(_pricingKey); break;
            case 'portal':
              Navigator.of(context).pushNamed('/portal'); break;
            case 'contact':
              _scrollTo(_contactKey); break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'home', child: Text('Home')),
          PopupMenuItem(value: 'features', child: Text('Features')),
          PopupMenuItem(value: 'pricing', child: Text('Pricing')),
          PopupMenuItem(value: 'portal', child: Text('Portal')),
          PopupMenuItem(value: 'contact', child: Text('Contact')),
        ],
        icon: const Icon(Icons.menu, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(

      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandedLogo(height: 28, color: Colors.white),
            SizedBox(width: 12),
            Flexible(child: Text('PG Book', overflow: TextOverflow.ellipsis)),
          ],
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        flexibleSpace: Builder(builder: (context) {
          final g = Theme.of(context).extension<AppGradients>();
          return Container(
            decoration: BoxDecoration(
              gradient: g?.primary ?? LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          );
        }),
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Show horizontal nav for wider screens, hamburger for mobile
              if (MediaQuery.of(context).size.width > 800) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDesktopNav(),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _openApp,
                      icon: const Icon(Icons.launch, color: Colors.white),
                      label: const Text('Launch App', style: TextStyle(color: Colors.white)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                );
              } else {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _openApp,
                      tooltip: 'Launch App',
                      icon: const Icon(Icons.launch, color: Colors.white),
                    ),
                    _navMenu(theme),
                  ],
                );
              }
            },
          ),
        ],
      ),

      bottomNavigationBar: const BrandedFooter(),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Hero
          Container(
            key: _homeKey,
            decoration: BoxDecoration(
              gradient: Theme.of(context).extension<AppGradients>()?.primary
                ?? LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: LayoutBuilder(builder: (ctx, c) {
                final isNarrow = c.maxWidth < 900;
                const imageUrl = 'https://pixabay.com/get/g78ebaffb50595f0b61db0f5bbfebaeee6c535b0fa031c62b8a473c3ae7bd4f1cb6f5375048b743ef6d08b67d4b1086341bdf1eaeef8db9ab74a4d85c8d487de0_1280.jpg';
                return Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      children: [
                        BrandedLogo(height: 48, color: Colors.white.withValues(alpha: 0.9)),
                        SizedBox(width: 16),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PG Book', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                              Text('by mVruksha Softwares', style: theme.textTheme.titleSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Simplify Your PG Management', style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Manage rooms, tenants, and payments seamlessly in one platform.', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.95))),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(onPressed: _openApp, icon: const Icon(Icons.open_in_new), label: const Text('Launch Application'), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary)),
                      OutlinedButton.icon(onPressed: () => _scrollTo(_contactKey), icon: const Icon(Icons.calendar_month, color: Colors.white), label: const Text('Request Demo'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)))
                    ]),
                    const SizedBox(height: 12),
                    Text('Trusted by PG owners across India to run their accommodations smoothly.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)))
                  ])),
                  if (!isNarrow) const SizedBox(width: 24),
                  if (!isNarrow) Expanded(child: AspectRatio(aspectRatio: 16 / 10, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(imageUrl, fit: BoxFit.cover))))
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
                final steps = const [
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
                final w = c.maxWidth;
                final isNarrow = w < 900;
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
                final w = c.maxWidth;
                final isNarrow = w < 900;
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
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Nav({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: TextButton(onPressed: onTap, child: Text(label, style: const TextStyle(color: Colors.white))),
      );
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.onTap});
  
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeatureCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12), child: Icon(data['icon'] as IconData, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['title'] as String, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(data['desc'] as String, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)
            ]),
          )
        ]),
      ),
    );
  }
}

final List<Map<String, Object>> _features = [
  {'icon': Icons.bed, 'title': 'Rooms & Beds', 'desc': 'Manage rooms, sharing categories and availability in real-time.'},
  {'icon': Icons.group, 'title': 'Tenants', 'desc': 'Onboard students, capture KYC, and assign beds quickly.'},
  {'icon': Icons.payments, 'title': 'Payments', 'desc': 'Record rent, food, and other fees with receipts.'},
  {'icon': Icons.receipt_long, 'title': 'Receipts', 'desc': 'Auto-generate and share receipts via PDF.'},
  {'icon': Icons.chat, 'title': 'Support Tickets', 'desc': 'Raise issues and track status with updates.'},
  {'icon': Icons.analytics, 'title': 'Reports & Exports', 'desc': 'Export students and room occupancy with filters.'},
];

class _Step {
  final IconData icon;
  final String title;
  final String desc;
  const _Step({required this.icon, required this.title, required this.desc});
}

class _StepTile extends StatelessWidget {
  final _Step step;
  const _StepTile({required this.step});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), child: Icon(step.icon, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(step.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(step.desc, style: theme.textTheme.bodySmall)
          ]))
        ]),
      ),
    );
  }
}

final List<Map<String, Object>> _plans = [
  {'name': 'Starter', 'price': '₹0', 'period': '/mo', 'points': ['Up to 20 tenants', 'Basic reports', 'Email support'], 'highlight': false},
  {'name': 'Pro', 'price': '₹499', 'period': '/mo', 'points': ['Unlimited tenants', 'Advanced exports', 'Priority support'], 'highlight': true},
  {'name': 'Business', 'price': '₹999', 'period': '/mo', 'points': ['Multi-branch', 'Custom reports', 'Dedicated success'], 'highlight': false},
];

class _PriceCard extends StatelessWidget {
  final Map<String, Object> data;
  final VoidCallback onStart;
  const _PriceCard({required this.data, required this.onStart});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = data['highlight'] == true;
    final List points = (data['points'] as List);
    return Card(
      color: highlight ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: highlight ? Theme.of(context).colorScheme.primary : Colors.transparent)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(data['name'] as String, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (highlight) Padding(padding: const EdgeInsets.only(left: 8), child: Container(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4)), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: const Text('Popular', style: TextStyle(color: Colors.white, fontSize: 11))))
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(data['price'] as String, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            Text(data['period'] as String, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey))
          ]),
          const SizedBox(height: 12),
          ...points.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Expanded(child: Text(p.toString()))]))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: onStart, style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary), child: const Text('Get Started')))
        ]),
      ),
    );
  }
}

final List<Map<String, String>> _testimonials = [
  {'quote': 'SmartStay simplified our tenant onboarding and fee tracking.', 'author': 'Rahul Verma', 'role': 'PG Owner, Bengaluru'},
  {'quote': 'Exports and receipts save hours every month. Highly recommended!', 'author': 'Anita Iyer', 'role': 'Hostel Admin, Pune'},
  {'quote': 'Support is responsive and features evolve fast.', 'author': 'Sanjay Patel', 'role': 'Owner, Ahmedabad'},
];

class _TestimonialCard extends StatelessWidget {
  final Map<String, String> data;
  const _TestimonialCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('"${data['quote']}"', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(data['author'] ?? '', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text(data['role'] ?? '', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
        ]),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  final VoidCallback onSubmit;
  const _ContactForm({required this.onSubmit});
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(children: [
        Align(alignment: Alignment.centerLeft, child: Text('PG Book (by mVruksha Softwares)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Your Name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _message, decoration: const InputDecoration(labelText: 'Message')))
        ]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () { if (_formKey.currentState?.validate() ?? false) { widget.onSubmit(); } }, icon: const Icon(Icons.send), label: const Text('Submit')))
      ]),
    );
  }
}

class _FooterLinksRow extends StatelessWidget {
  const _FooterLinksRow();
  Future<void> _open(BuildContext context, String route) async {
    try {
      if (!context.mounted) return;
      Navigator.of(context).pushNamed(route);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
      TextButton(onPressed: () => _open(context, '/portal'), child: Text('Portal', style: textStyle)),
      TextButton(onPressed: () => _open(context, '/register'), child: Text('Register', style: textStyle)),
      TextButton(onPressed: () => _open(context, '/login'), child: Text('Login', style: textStyle)),
      TextButton(onPressed: () => _open(context, '/admin-login'), child: Text('Admin Login', style: textStyle)),
      TextButton(onPressed: () => _open(context, '/'), child: Text('Home', style: textStyle))
    ]);
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();
  Future<void> _launch(Uri url) async { try { await launchUrl(url, webOnlyWindowName: '_blank'); } catch (_) {} }
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: () => _launch(Uri.parse('mailto:contact@mvsoftwares.example')), icon: const Icon(Icons.mail), color: Colors.blueGrey),
      IconButton(onPressed: () => _launch(Uri.parse('https://www.linkedin.com/company/mvruksha-softwares/')), icon: const Icon(Icons.business_center), color: Colors.blueGrey),
      IconButton(onPressed: () => _launch(Uri.parse('https://x.com/')), icon: const Icon(Icons.alternate_email), color: Colors.blueGrey)
    ]);
  }
}
