/// Trip-level inputs that drive complexity-based duration adjustments.
/// Constructed from form data at trip-creation time; no Trip import needed.
class TripComplexityProfile {
  final int  numberOfCities;
  final int  numberOfDays;
  final int  numberOfGuests;
  final bool hasSignatureExperiences;
  final bool hasMobilityRequirements;
  final bool hasPrivateTransport;

  const TripComplexityProfile({
    this.numberOfCities           = 1,
    this.numberOfDays             = 1,
    this.numberOfGuests           = 1,
    this.hasSignatureExperiences  = false,
    this.hasMobilityRequirements  = false,
    this.hasPrivateTransport      = false,
  });

  @override
  String toString() =>
      'TripComplexityProfile('
      'cities=$numberOfCities, '
      'days=$numberOfDays, '
      'guests=$numberOfGuests, '
      'signatureExp=$hasSignatureExperiences, '
      'mobility=$hasMobilityRequirements, '
      'privateTransport=$hasPrivateTransport)';
}
