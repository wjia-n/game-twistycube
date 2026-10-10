import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/cube_themes.dart';
import '../widgets/ui_bits.dart';

/// Pro screen: honest Free-vs-Pro comparison, real Play Billing purchases
/// (twistycubepro / twistycubecoffee / twistycubechocolate), tip jar, and
/// restore. Graceful when the store isn't configured yet.
class ProScreen extends StatefulWidget {
  final CubeAudio audio;
  final CubeSettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final StoreService _store = StoreService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initStore();
    _store.lastThanks.addListener(_onThanks);
    _store.purchaseError.addListener(_onPurchaseError);
  }

  Future<void> _initStore() async {
    await _store.init();
    if (mounted) setState(() => _loading = false);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg != null && mounted) {
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
      _store.lastThanks.value = null;
    }
  }

  void _onPurchaseError() {
    final err = _store.purchaseError.value;
    if (err != null && mounted) {
      widget.audio.invalid();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      _store.purchaseError.value = null;
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.purchaseError.removeListener(_onPurchaseError);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CubeThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.table,
      appBar: AppBar(
        backgroundColor: theme.table,
        foregroundColor: theme.panel,
        title: const Text('Twisty Cube Pro',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _heroCard(theme),
              const SizedBox(height: 12),
              _compareCard(theme),
              const SizedBox(height: 12),
              _buyCard(theme),
              const SizedBox(height: 12),
              _tipJar(theme),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard(CubeThemeDef theme) {
    final isPro = widget.settings.isPro;
    return PanelCard(
      theme: theme,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF8A6D3B),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPro ? 'You\'re Pro!' : 'Go Pro, twist more',
                  style: TextStyle(
                      color: theme.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                Text(
                  isPro
                      ? 'Every cube, theme and mode is unlocked. Thank you!'
                      : 'One purchase. Every cube unlocked forever.',
                  style:
                      TextStyle(color: theme.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareCard(CubeThemeDef theme) {
    final rows = [
      ('Pocket 2×2 cube', true, true),
      ('Classic 3×3 cube', false, true),
      ('Master 4×4 cube', false, true),
      ('Relaxed mode', true, true),
      ('Timed mode', false, true),
      ('8 toy themes', true, true),
      ('4 premium themes', false, true),
      ('Custom theme creator', false, true),
      ('8 sticker styles', false, true),
      ('Best-time records', true, true),
    ];
    return PanelCard(
      theme: theme,
      child: Column(
        children: [
          _compareHeader(theme),
          const SizedBox(height: 8),
          for (final (label, free, pro) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: theme.ink,
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      free
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: free
                          ? const Color(0xFF35A853)
                          : theme.inkSoft.withValues(alpha: 0.35),
                      size: 20,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Icon(
                      pro
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: const Color(0xFF8A6D3B),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compareHeader(CubeThemeDef theme) {
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        SizedBox(
          width: 52,
          child: Text('FREE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.inkSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
        SizedBox(
          width: 52,
          child: Text('PRO',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.accentDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buyCard(CubeThemeDef theme) {
    if (widget.settings.isPro) {
      return PanelCard(
        theme: theme,
        child: Row(
          children: [
            const Icon(Icons.verified_rounded,
                color: Color(0xFF35A853), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pro is active on this device.',
                style: TextStyle(
                    color: theme.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return PanelCard(
        theme: theme,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final pro = _store.proProduct;
    if (!_store.storeReady || pro == null) {
      return PanelCard(
        theme: theme,
        child: Column(
          children: [
            Icon(Icons.storefront_rounded,
                color: theme.inkSoft, size: 32),
            const SizedBox(height: 8),
            Text(
              'Pro purchases will appear here once the store products '
              'are set up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                widget.audio.click();
                _store.restore();
              },
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore purchase'),
            ),
          ],
        ),
      );
    }
    return PanelCard(
      theme: theme,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pro.title,
                        style: TextStyle(
                            color: theme.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    Text(pro.description,
                        style: TextStyle(
                            color: theme.inkSoft, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                pro.price,
                style: TextStyle(
                    color: theme.accentDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: _store.purchaseInProgress,
            builder: (_, busy, _) => SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        widget.audio.click();
                        _store.buyPro();
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.workspace_premium_rounded),
                label: Text(busy ? 'Working…' : 'UNLOCK PRO'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8A6D3B),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              widget.audio.click();
              _store.restore();
            },
            icon: const Icon(Icons.restore_rounded, size: 16),
            label: const Text('Restore purchase'),
          ),
        ],
      ),
    );
  }

  Widget _tipJar(CubeThemeDef theme) {
    if (_loading || !_store.storeReady) return const SizedBox.shrink();
    final coffee = _store.coffeeProduct;
    final choco = _store.chocolateProduct;
    if (coffee == null && choco == null) {
      return const SizedBox.shrink();
    }
    return PanelCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  color: theme.accentDark, size: 22),
              const SizedBox(width: 8),
              Text('Tip jar',
                  style: TextStyle(
                      color: theme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Twisty Cube is made with love by an indie maker. '
            'Tips keep the cubes twisting!',
            style: TextStyle(color: theme.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (coffee != null)
                Expanded(child: _tipButton(theme, coffee)),
              if (coffee != null && choco != null)
                const SizedBox(width: 10),
              if (choco != null)
                Expanded(child: _tipButton(theme, choco)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipButton(CubeThemeDef theme, dynamic product) {
    final isCoffee = product.id == StoreService.coffeeId;
    return OutlinedButton.icon(
      onPressed: () {
        widget.audio.click();
        _store.buyTip(product);
      },
      icon: Icon(isCoffee
          ? Icons.coffee_rounded
          : Icons.icecream_rounded),
      label: Text(
          '${isCoffee ? 'Coffee' : 'Chocolate'} · ${product.price}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.accentDark,
        side: BorderSide(color: theme.accent),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}