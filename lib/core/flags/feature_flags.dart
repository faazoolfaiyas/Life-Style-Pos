/// Opt-in rollout. Existing screens stay untouched unless explicitly enabled.
class FeatureFlags {
  const FeatureFlags._();

  static const bool templateDrivenWizards =
      bool.fromEnvironment('LIFESTYLE_FLOW_V2', defaultValue: false);
}
