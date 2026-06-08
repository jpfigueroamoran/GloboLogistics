import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/operador_score.dart';
import '../providers/operador_score_provider.dart';

class ScoreOperadoresPage extends ConsumerWidget {
  const ScoreOperadoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(operadorScoresProvider);

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(scores: scores),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: scores.isEmpty
                ? const Center(child: Text('Sin datos de operadores'))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ranking
                      Expanded(
                        flex: 2,
                        child: _RankingList(scores: scores),
                      ),
                      const SizedBox(width: GloboSpacing.md),
                      // Detalle del top 1
                      Expanded(
                        flex: 3,
                        child: _ScoreDetalle(score: scores.first),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Encabezado con resumen ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final List<OperadorScore> scores;
  const _Header({required this.scores});

  @override
  Widget build(BuildContext context) {
    final excelentes = scores.where((s) => s.nivel == NivelScore.excelente).length;
    final criticos   = scores.where((s) => s.nivel == NivelScore.critico).length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Score de Operadores', style: GloboTypography.headlineMedium),
              Text(
                '${scores.length} operadores evaluados',
                style: GloboTypography.bodyMedium,
              ),
            ],
          ),
        ),
        _SummaryCard(
          label: 'Excelentes',
          value: excelentes,
          color: GloboColors.successAccent,
        ),
        const SizedBox(width: GloboSpacing.sm),
        _SummaryCard(
          label: 'Críticos',
          value: criticos,
          color: GloboColors.error,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: GloboTypography.displayMedium.copyWith(color: color),
          ),
          Text(label, style: GloboTypography.caption),
        ],
      ),
    );
  }
}

// ── Lista ranking ─────────────────────────────────────────────────────────────

class _RankingList extends StatelessWidget {
  final List<OperadorScore> scores;
  const _RankingList({required this.scores});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Text('Ranking', style: GloboTypography.titleMedium),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: scores.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (ctx, i) => _RankingRow(
                score: scores[i],
                position: i + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final OperadorScore score;
  final int position;
  const _RankingRow({required this.score, required this.position});

  Color get _nivelColor => switch (score.nivel) {
        NivelScore.excelente => GloboColors.successAccent,
        NivelScore.bueno     => GloboColors.accentBright,
        NivelScore.regular   => GloboColors.warningAccent,
        NivelScore.critico   => GloboColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _nivelColor.withAlpha(30),
        child: Text(
          '$position',
          style: TextStyle(
            color: _nivelColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(score.nombreOperador, style: GloboTypography.titleMedium),
      subtitle: Text(
        '${score.totalViajes} viajes',
        style: GloboTypography.caption,
      ),
      trailing: _ScoreBadge(score: score.scoreTotal, color: _nivelColor),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final double score;
  final Color color;
  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: GloboRadius.chipRadius,
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        score.toStringAsFixed(0),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ── Detalle del operador seleccionado ─────────────────────────────────────────

class _ScoreDetalle extends StatelessWidget {
  final OperadorScore score;
  const _ScoreDetalle({required this.score});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(score.nombreOperador,
                          style: GloboTypography.headlineMedium),
                      const SizedBox(height: 2),
                      _NivelChip(nivel: score.nivel),
                    ],
                  ),
                ),
                _BigScore(score: score.scoreTotal),
              ],
            ),
            const SizedBox(height: GloboSpacing.lg),
            Text('Desglose del Score',
                style: GloboTypography.titleMedium.copyWith(
                    color: GloboColors.textTertiary, letterSpacing: 1)),
            const SizedBox(height: GloboSpacing.md),
            _ScoreBar(
              label: 'Eficiencia combustible',
              value: score.scoreVarianza,
              weight: 40,
              color: GloboColors.accentBright,
            ),
            const SizedBox(height: GloboSpacing.sm),
            _ScoreBar(
              label: 'Seguridad (SOS-libre)',
              value: score.scoreSOS,
              weight: 30,
              color: GloboColors.successAccent,
            ),
            const SizedBox(height: GloboSpacing.sm),
            _ScoreBar(
              label: 'Tasa de completitud',
              value: score.scoreCompletitud,
              weight: 30,
              color: GloboColors.warningAccent,
            ),
            const Spacer(),
            const Divider(),
            const SizedBox(height: GloboSpacing.sm),
            _StatsRow(score: score),
          ],
        ),
      ),
    );
  }
}

class _BigScore extends StatelessWidget {
  final double score;
  const _BigScore({required this.score});

  Color get _color {
    if (score >= 85) return GloboColors.successAccent;
    if (score >= 65) return GloboColors.accentBright;
    if (score >= 45) return GloboColors.warningAccent;
    return GloboColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color.withAlpha(20),
        border: Border.all(color: _color, width: 2),
      ),
      child: Center(
        child: Text(
          score.toStringAsFixed(0),
          style: TextStyle(
            color: _color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NivelChip extends StatelessWidget {
  final NivelScore nivel;
  const _NivelChip({required this.nivel});

  String get _label => switch (nivel) {
        NivelScore.excelente => 'EXCELENTE',
        NivelScore.bueno     => 'BUENO',
        NivelScore.regular   => 'REGULAR',
        NivelScore.critico   => 'CRÍTICO',
      };

  Color get _color => switch (nivel) {
        NivelScore.excelente => GloboColors.successAccent,
        NivelScore.bueno     => GloboColors.accentBright,
        NivelScore.regular   => GloboColors.warningAccent,
        NivelScore.critico   => GloboColors.error,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withAlpha(25),
        borderRadius: GloboRadius.chipRadius,
      ),
      child: Text(
        _label,
        style: GloboTypography.labelSmall.copyWith(color: _color),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;    // 0–100
  final int weight;      // porcentaje de peso
  final Color color;

  const _ScoreBar({
    required this.label,
    required this.value,
    required this.weight,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: GloboTypography.bodyMedium),
            ),
            Text(
              '${value.toStringAsFixed(0)} / 100  ·  peso $weight%',
              style: GloboTypography.caption,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: color.withAlpha(25),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final OperadorScore score;
  const _StatsRow({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(label: 'Viajes', value: '${score.totalViajes}'),
        _StatItem(
            label: 'Banderas',
            value: '${score.viajesBanderaRoja}',
            color: score.viajesBanderaRoja > 0 ? GloboColors.error : null),
        _StatItem(
            label: 'SOS',
            value: '${score.alertasSOS}',
            color: score.alertasSOS > 0 ? GloboColors.sosPrimary : null),
        _StatItem(
            label: 'Var. media',
            value: '${(score.promedioVarianza * 100).toStringAsFixed(1)} %'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GloboTypography.headlineMedium.copyWith(
            color: color ?? GloboColors.textPrimary,
          ),
        ),
        Text(label, style: GloboTypography.caption),
      ],
    );
  }
}
