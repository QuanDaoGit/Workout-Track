/// Pure greedy plate-loader. Given a target total weight and a bar weight,
/// returns the plates to load on ONE side of the bar (the other side mirrors).
///
/// Plate denominations default to a standard ISO Olympic set
/// `[25, 20, 15, 10, 5, 2.5, 1.25]` kg, largest first.
///
/// Returns:
///   - empty list if the target is at or below the bar weight (no plates needed)
///   - empty list if the remaining amount can't be loaded exactly from the
///     supplied plates (no asymmetric loads)
class PlateCalculator {
  static const List<double> defaultPlates = [25, 20, 15, 10, 5, 2.5, 1.25];
  static const double defaultBarKg = 20;

  /// Greedy fill. `targetKg` is the total weight including the bar.
  /// Returns plates per side in descending order.
  static List<double> platesPerSide(
    double targetKg, {
    double barKg = defaultBarKg,
    List<double> plates = defaultPlates,
  }) {
    if (targetKg <= barKg) return const [];
    var perSide = (targetKg - barKg) / 2;
    final result = <double>[];
    for (final plate in plates) {
      while (perSide >= plate - 0.001) {
        result.add(plate);
        perSide -= plate;
      }
    }
    // If we couldn't exactly load the requested weight, return empty —
    // callers render an "exact load not possible" hint.
    if (perSide > 0.001) return const [];
    return result;
  }

  /// Reverse direction: total bar weight for a per-side stack.
  /// Unit-agnostic — pass values in whatever unit the caller works in.
  static double totalWeight(
    List<double> perSide, {
    double barKg = defaultBarKg,
  }) => barKg + 2 * perSide.fold<double>(0, (sum, plate) => sum + plate);
}
