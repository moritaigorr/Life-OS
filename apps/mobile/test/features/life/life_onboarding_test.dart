import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/life/life_onboarding.dart';

void main() {
  test('keeps the life vision while advancing to the goals step', () {
    const state = LifeOnboardingState(
      status: LifeOnboardingStatus.inProgress,
      currentStep: 0,
      lifeVision: 'Ter tempo para cuidar da saúde',
    );

    expect(state.nextStep().currentStep, 1);
    expect(state.nextStep().lifeVision, 'Ter tempo para cuidar da saúde');
    expect(state.nextStep().status, LifeOnboardingStatus.inProgress);
  });

  test('skipping preserves progress so onboarding can resume', () {
    const state = LifeOnboardingState(
      status: LifeOnboardingStatus.inProgress,
      currentStep: 1,
      lifeVision: 'Terminar um projeto pessoal',
    );

    final skipped = state.skip();
    expect(skipped.status, LifeOnboardingStatus.skipped);
    expect(skipped.currentStep, 1);
    expect(skipped.lifeVision, 'Terminar um projeto pessoal');
    expect(skipped.resume().status, LifeOnboardingStatus.inProgress);
  });

  test('round trips persisted onboarding progress', () {
    const state = LifeOnboardingState(
      status: LifeOnboardingStatus.inProgress,
      currentStep: 1,
      lifeVision: 'Uma vida com mais espaço',
    );

    expect(LifeOnboardingState.fromJson(state.toJson()), state);
  });
}
