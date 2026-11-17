import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Words in a supplier name that tell the kind of business, and its icon.
const _byKind = [
  (['freight', 'logistic', 'transport', 'shipping', 'courier'], Icons.local_shipping_rounded),
  (['energy', 'power', 'electric', 'solar'], Icons.bolt_rounded),
  (['hosting', 'cloud', 'server'], Icons.cloud_rounded),
  (['software', 'tech', 'digital', 'data'], Icons.memory_rounded),
  (['paper', 'print'], Icons.description_rounded),
  (['legal', 'law', 'advisor', 'notary'], Icons.gavel_rounded),
  (['office', 'supply', 'supplies'], Icons.inventory_2_rounded),
  (['clean'], Icons.cleaning_services_rounded),
  (['marketing', 'media', 'ads'], Icons.campaign_rounded),
  (['coffee', 'catering', 'food'], Icons.coffee_rounded),
];

const _fallback = [
  Icons.storefront_rounded,
  Icons.business_center_rounded,
  Icons.handshake_rounded,
  Icons.apartment_rounded,
];

/// A filled icon chosen from the kind of business in the supplier name, so a supplier always
/// gets the same one. Names that say nothing get one of a few generic icons.
class SupplierIcon extends StatelessWidget {
  const SupplierIcon({super.key, required this.supplier, this.size = 40});

  final String supplier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = supplier.toLowerCase();
    final seed = supplier.codeUnits.fold(0, (sum, unit) => sum + unit);
    final icon =
        _byKind.where((kind) => kind.$1.any(name.contains)).map((kind) => kind.$2).firstOrNull ??
        _fallback[seed % _fallback.length];
    return Icon(icon, size: size, color: seed.isEven ? AppColors.ink : AppColors.accent);
  }
}
