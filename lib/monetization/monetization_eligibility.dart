/// Fail-closed advertising and purchase eligibility policy.
/// This is local policy only: it does not collect consent, verify age,
/// connect to an ad network, or verify store purchases.
enum AudienceClass { unknown, child, general }
enum ConsentChoice { unknown, denied, granted }

class MonetizationEligibility {
  AudienceClass audience;
  ConsentChoice adConsent;
  bool adsRemoved;
  bool premiumEntitled;

  MonetizationEligibility({
    this.audience = AudienceClass.unknown,
    this.adConsent = ConsentChoice.unknown,
    this.adsRemoved = false,
    this.premiumEntitled = false,
  });

  /// An unknown audience or consent choice must never show advertising.
  /// Real implementations must additionally honor platform privacy controls.
  bool get mayRequestAds =>
      audience == AudienceClass.general &&
      adConsent == ConsentChoice.granted &&
      !adsRemoved;

  /// Reward offers are optional and are never necessary for ordinary play.
  bool get mayOfferRewardedAd => mayRequestAds;

  /// Only call this at a completed-round boundary and after pacing checks.
  bool mayShowInterstitial({required bool naturalBreak, required bool paced}) =>
      mayRequestAds && naturalBreak && paced;

  /// Store entitlements must come from verified transactions, not this flag.
  bool get premiumAvailable => premiumEntitled;

  void revokeConsent() => adConsent = ConsentChoice.denied;
}
