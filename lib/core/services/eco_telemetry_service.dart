import '../../models/eco_footprint_telemetry.dart';

class EcoTelemetryService {
  static final EcoTelemetryService _instance = EcoTelemetryService._internal();
  factory EcoTelemetryService() => _instance;
  EcoTelemetryService._internal();

  static const List<String> supportedVehicleTypes = [
    'Diesel SUV',
    'Petrol Car',
    'Electric EV',
    'Motorcycle',
  ];

  /// Computes accurate carbon footprint and fuel telemetry
  EcoFootprintTelemetry calculateTelemetry({
    required double distanceKm,
    required String vehicleType,
    double fuelPricePerUnit = 95.0, // Default INR per litre or kWh
    String currencyCode = 'INR',
  }) {
    if (distanceKm <= 0) {
      return EcoFootprintTelemetry(
        totalDistanceKm: 0,
        vehicleType: vehicleType,
        fuelBurnedLitres: 0,
        co2EmittedKg: 0,
        treesRequiredToOffset: 0,
        estimatedFuelCost: 0,
        currencyCode: currencyCode,
      );
    }

    double fuelBurned = 0.0;
    double co2Kg = 0.0;
    double estimatedCost = 0.0;

    switch (vehicleType) {
      case 'Diesel SUV':
        // ~12 km/litre, 2.68 kg CO2/L
        fuelBurned = distanceKm / 12.0;
        co2Kg = fuelBurned * 2.68;
        estimatedCost = fuelBurned * (fuelPricePerUnit > 0 ? fuelPricePerUnit : 90.0);
        break;

      case 'Petrol Car':
        // ~14 km/litre, 2.31 kg CO2/L
        fuelBurned = distanceKm / 14.0;
        co2Kg = fuelBurned * 2.31;
        estimatedCost = fuelBurned * (fuelPricePerUnit > 0 ? fuelPricePerUnit : 100.0);
        break;

      case 'Electric EV':
        // 0.16 kWh/km, ~0.05 kg CO2/km grid average
        fuelBurned = distanceKm * 0.16; // Units in kWh
        co2Kg = distanceKm * 0.05;
        estimatedCost = fuelBurned * 10.0; // ~10 INR per commercial EV unit
        break;

      case 'Motorcycle':
      default:
        // ~35 km/litre, 2.31 kg CO2/L
        fuelBurned = distanceKm / 35.0;
        co2Kg = fuelBurned * 2.31;
        estimatedCost = fuelBurned * (fuelPricePerUnit > 0 ? fuelPricePerUnit : 100.0);
        break;
    }

    // 1 mature tree absorbs ~22 kg CO2 per year
    final treesRequired = (co2Kg / 22.0).ceil();

    return EcoFootprintTelemetry(
      totalDistanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      vehicleType: vehicleType,
      fuelBurnedLitres: double.parse(fuelBurned.toStringAsFixed(1)),
      co2EmittedKg: double.parse(co2Kg.toStringAsFixed(1)),
      treesRequiredToOffset: treesRequired,
      estimatedFuelCost: double.parse(estimatedCost.toStringAsFixed(0)),
      currencyCode: currencyCode,
    );
  }
}
