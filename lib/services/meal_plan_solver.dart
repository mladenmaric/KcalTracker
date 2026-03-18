import '../models/plan_item.dart';

/// Result returned after optimisation.
class SolverResult {
  final List<double> optimalGrams;
  final double totalKcal;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final int iterations;

  const SolverResult({
    required this.optimalGrams,
    required this.totalKcal,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.iterations,
  });
}

/// Box-constrained Quadratic Programming via Projected Gradient Descent.
///
/// Problem:
///   minimise  w_k*(Σ c_i·x_i − G_k)²  +  w_p*(Σ p_i·x_i − G_p)²
///           + w_c*(Σ b_i·x_i − G_c)²  +  w_f*(Σ f_i·x_i − G_f)²
///   subject to  lb_i ≤ x_i ≤ ub_i   for each food i
///
/// Each weight w_k = 1/G_k² so that a 1 % error in every macro contributes
/// equally to the loss, regardless of scale.
///
/// The step size is 1/L where L is the Lipschitz constant of the gradient,
/// giving guaranteed convergence without any line-search.
class MealPlanSolver {
  MealPlanSolver._();

  static SolverResult solve({
    required List<PlanItem> items,
    required double goalKcal,
    required double goalProteinG,
    required double goalCarbsG,
    required double goalFatG,
    int maxIter = 3000,
    double tol = 1e-8,
  }) {
    final n = items.length;
    if (n == 0) {
      return SolverResult(
        optimalGrams: [],
        totalKcal: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFat: 0,
        iterations: 0,
      );
    }

    // Per-gram coefficients
    final c = items.map((i) => i.kcalPerG).toList();
    final p = items.map((i) => i.proteinPerG).toList();
    final b = items.map((i) => i.carbsPerG).toList();
    final f = items.map((i) => i.fatPerG).toList();

    final lb = items.map((i) => i.minGrams).toList();
    final ub = items.map((i) => i.maxGrams).toList();

    // Weights — avoid division by zero
    final wk = goalKcal    > 0 ? 1.0 / (goalKcal    * goalKcal)    : 1.0;
    final wp = goalProteinG > 0 ? 1.0 / (goalProteinG * goalProteinG) : 1.0;
    final wc = goalCarbsG  > 0 ? 1.0 / (goalCarbsG  * goalCarbsG)  : 1.0;
    final wf = goalFatG    > 0 ? 1.0 / (goalFatG    * goalFatG)    : 1.0;

    // Lipschitz constant L of ∇f:
    // L = 2 * (wk*‖c‖² + wp*‖p‖² + wc*‖b‖² + wf*‖f‖²)
    double L = 0;
    for (int i = 0; i < n; i++) {
      L += wk * c[i] * c[i] +
           wp * p[i] * p[i] +
           wc * b[i] * b[i] +
           wf * f[i] * f[i];
    }
    L *= 2;
    final lr = L > 0 ? 0.9 / L : 1e-4; // step size

    // Initialise at midpoint of each food's range
    var x = List.generate(n, (i) => (lb[i] + ub[i]) / 2);

    int iter = 0;
    for (; iter < maxIter; iter++) {
      // Compute current macro totals
      double kcalT = 0, protT = 0, carbT = 0, fatT = 0;
      for (int i = 0; i < n; i++) {
        kcalT += c[i] * x[i];
        protT += p[i] * x[i];
        carbT += b[i] * x[i];
        fatT  += f[i] * x[i];
      }

      // Residuals
      final rk = kcalT - goalKcal;
      final rp = protT - goalProteinG;
      final rc = carbT - goalCarbsG;
      final rf = fatT  - goalFatG;

      // Gradient and update
      double gradNormSq = 0;
      final xNew = List<double>.filled(n, 0);
      for (int i = 0; i < n; i++) {
        final grad = 2 * (wk * c[i] * rk +
                          wp * p[i] * rp +
                          wc * b[i] * rc +
                          wf * f[i] * rf);
        gradNormSq += grad * grad;
        xNew[i] = (x[i] - lr * grad).clamp(lb[i], ub[i]);
      }

      x = xNew;
      if (gradNormSq < tol) break;
    }

    // Final totals
    double kcalF = 0, protF = 0, carbF = 0, fatF = 0;
    for (int i = 0; i < n; i++) {
      kcalF += c[i] * x[i];
      protF += p[i] * x[i];
      carbF += b[i] * x[i];
      fatF  += f[i] * x[i];
    }

    return SolverResult(
      optimalGrams: x,
      totalKcal: kcalF,
      totalProtein: protF,
      totalCarbs: carbF,
      totalFat: fatF,
      iterations: iter,
    );
  }
}
