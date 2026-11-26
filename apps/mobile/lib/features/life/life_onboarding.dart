enum LifeOnboardingStatus { inProgress, skipped, completed }

class LifeOnboardingState {
  const LifeOnboardingState({
    required this.status,
    required this.currentStep,
    this.lifeVision,
  });

  final LifeOnboardingStatus status;
  final int currentStep;
  final String? lifeVision;

  LifeOnboardingState nextStep({String? vision}) => LifeOnboardingState(
    status: LifeOnboardingStatus.inProgress,
    currentStep: 1,
    lifeVision: vision?.trim().isNotEmpty == true ? vision!.trim() : lifeVision,
  );

  LifeOnboardingState skip() => LifeOnboardingState(
    status: LifeOnboardingStatus.skipped,
    currentStep: currentStep,
    lifeVision: lifeVision,
  );

  LifeOnboardingState resume() => LifeOnboardingState(
    status: LifeOnboardingStatus.inProgress,
    currentStep: currentStep,
    lifeVision: lifeVision,
  );

  LifeOnboardingState complete({String? vision}) => LifeOnboardingState(
    status: LifeOnboardingStatus.completed,
    currentStep: 1,
    lifeVision: vision?.trim().isNotEmpty == true ? vision!.trim() : lifeVision,
  );

  Map<String, Object?> toJson() => {
    'status': switch (status) {
      LifeOnboardingStatus.inProgress => 'in_progress',
      LifeOnboardingStatus.skipped => 'skipped',
      LifeOnboardingStatus.completed => 'completed',
    },
    'current_step': currentStep,
    'life_vision': lifeVision,
  };

  factory LifeOnboardingState.fromJson(Map<String, dynamic> json) =>
      LifeOnboardingState(
        status: switch (json['status'] as String) {
          'in_progress' => LifeOnboardingStatus.inProgress,
          'skipped' => LifeOnboardingStatus.skipped,
          'completed' => LifeOnboardingStatus.completed,
          _ => throw const FormatException('Estado de onboarding inválido.'),
        },
        currentStep: json['current_step'] as int,
        lifeVision: json['life_vision'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is LifeOnboardingState &&
      other.status == status &&
      other.currentStep == currentStep &&
      other.lifeVision == lifeVision;

  @override
  int get hashCode => Object.hash(status, currentStep, lifeVision);
}

String? validateLifeVision(String value) {
  final vision = value.trim();
  if (vision.isEmpty) return 'Escreva uma frase ou escolha pular esta etapa.';
  if (vision.length > 2000) return 'Use até 2.000 caracteres.';
  return null;
}
