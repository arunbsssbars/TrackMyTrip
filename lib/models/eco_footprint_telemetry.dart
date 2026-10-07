class EcoFootprintTelemetry {
  final double totalDistanceKm;
  final String vehicleType; // 'Diesel SUV', 'Petrol Car', 'Electric EV', 'Motorcycle'
  final double fuelBurnedLitres;
  final double co2EmittedKg;
  final int treesRequiredToOffset;
  final double estimatedFuelCost;
  final String currencyCode;

  const EcoFootprintTelemetry({
    required this.totalDistanceKm,
    required this.vehicleType,
    required this.fuelBurnedLitres,
    required this.co2EmittedKg,
    required this.treesRequiredToOffset,
    required this.estimatedFuelCost,
    this.currencyCode = 'INR',
  });

  Map<String, dynamic> toJson() => {
        'totalDistanceKm': totalDistanceKm,
        'vehicleType': vehicleType,
        'fuelBurnedLitres': fuelBurnedLitres,
        'co2EmittedKg': co2EmittedKg,
        'treesRequiredToOffset': treesRequiredToOffset,
        'estimatedFuelCost': estimatedFuelCost,
        'currencyCode': currencyCode,
      };

  factory EcoFootprintTelemetry.fromJson(Map<String, dynamic> json) {
    return EcoFootprintTelemetry(
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      vehicleType: json['vehicleType'] as String? ?? 'Diesel SUV',
      fuelBurnedLitres: (json['fuelBurnedLitres'] as num?)?.toDouble() ?? 0.0,
      co2EmittedKg: (json['co2EmittedKg'] as num?)?.toDouble() ?? 0.0,
      treesRequiredToOffset: (json['treesRequiredToOffset'] as num?)?.toInt() ?? 0,
      estimatedFuelCost: (json['estimatedFuelCost'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currencyCode'] as String? ?? 'INR',
    );
  }

  EcoFootprintTelemetry copyWith({
    double? totalDistanceKm,
    String? vehicleType,
    double? fuelBurnedLitres,
    double? co2EmittedKg,
    int? treesRequiredToOffset,
    double? estimatedFuelCost,
    String? currencyCode,
  }) {
    return EcoFootprintTelemetry(
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      vehicleType: vehicleType ?? this.vehicleType,
      fuelBurnedLitres: fuelBurnedLitres ?? this.fuelBurnedLitres,
      co2EmittedKg: co2EmittedKg ?? this.co2EmittedKg,
      treesRequiredToOffset: treesRequiredToOffset ?? this.treesRequiredToOffset,
      estimatedFuelCost: estimatedFuelCost ?? this.estimatedFuelCost,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
