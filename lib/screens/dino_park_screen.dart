import 'package:flutter/material.dart';

import '../models/dino_species.dart';
import '../services/dino_collection.dart';
import '../services/sound_service.dart';
import '../widgets/dino_portrait.dart';
import '../widgets/menu_background.dart';

const _cardColor = Color(0xFF2B2118);
const _gold = Color(0xFFFFC107);

/// The dinosaur collection: every species, hatched ones in full and the
/// rest as silhouettes. Rebuilds live as hatches and selection change.
class DinoParkScreen extends StatelessWidget {
  const DinoParkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MenuBackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('VƯỜN KHỦNG LONG'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([DinoCollection.hatchCounts, DinoCollection.selected]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Đã sưu tầm ${DinoCollection.ownedCount}/${DinoSpecies.values.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bắn nổ hoặc làm rơi trứng phát sáng để ấp khủng long mới.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: [for (final species in DinoSpecies.values) _SpeciesCard(species: species)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesCard extends StatelessWidget {
  final DinoSpecies species;

  const _SpeciesCard({required this.species});

  @override
  Widget build(BuildContext context) {
    final owned = DinoCollection.isOwned(species);
    final selected = DinoCollection.selected.value == species;
    final info = species.info;
    final hatched = DinoCollection.hatchCount(species);

    return Material(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? _gold : (owned ? info.color : Colors.white24), width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!owned) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Chưa ấp được loài này. Hãy tìm trứng phát sáng trong game!')),
              );
            return;
          }
          SoundService.playMenuConfirm();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DinoDetailScreen(species: species)));
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(child: Center(child: DinoPortrait(species: species, size: 128, locked: !owned))),
              const SizedBox(height: 6),
              Text(
                owned ? info.nameVi : '???',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                !owned
                    ? 'Chưa ấp'
                    : selected
                    ? 'Đang đồng hành'
                    : (hatched > 0 ? 'Đã ấp: $hatched' : 'Bạn đồng hành đầu tiên'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _gold : Colors.white60,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A hatched species' encyclopedia card, its companion skill, and a
/// button to make it the companion for the next game.
class DinoDetailScreen extends StatelessWidget {
  final DinoSpecies species;

  const DinoDetailScreen({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final info = species.info;
    return MenuBackgroundScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(info.nameVi.toUpperCase()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(child: DinoPortrait(species: species, size: 160)),
            const SizedBox(height: 12),
            Text(
              info.nameVi,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              info.scientificName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            _Section(
              children: [
                _InfoRow(icon: Icons.schedule, label: 'Thời kỳ', value: info.period),
                _InfoRow(icon: Icons.straighten, label: 'Kích thước', value: info.size),
                _InfoRow(icon: Icons.fitness_center, label: 'Cân nặng', value: info.weight),
                _InfoRow(icon: Icons.restaurant, label: 'Thức ăn', value: info.diet),
                _InfoRow(icon: Icons.public, label: 'Hóa thạch tìm thấy ở', value: info.foundIn),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Có thể bạn chưa biết',
              children: [
                for (final fact in info.facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: _gold, fontSize: 15)),
                        Expanded(
                          child: Text(fact, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Kỹ năng đồng hành: ${info.ability.title}',
              children: [
                Text(info.ability.description, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
              ],
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<DinoSpecies>(
              valueListenable: DinoCollection.selected,
              builder: (context, selected, _) {
                final isSelected = selected == species;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? Colors.white24 : const Color(0xFF6D4C41),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSelected
                      ? null
                      : () {
                          SoundService.playMenuConfirm();
                          DinoCollection.select(species);
                        },
                  child: Text(
                    isSelected ? 'ĐANG ĐỒNG HÀNH' : 'CHỌN LÀM BẠN ĐỒNG HÀNH',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Section({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _cardColor.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white60, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white60)),
                  TextSpan(text: value, style: const TextStyle(color: Colors.white)),
                ],
              ),
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
