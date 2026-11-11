import 'package:flutter/widgets.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

import '../models/simulation_scenario.dart';

class SimulationStrings {
  static String categoryName(
    BuildContext context,
    SimulationCategory category,
  ) {
    switch (category.id) {
      case 'myopia':
        return context.l10n.simCatMyopia;
      case 'multifocal':
        return context.l10n.simCatMultifocal;
      case 'bifocal':
        return context.l10n.simCatBifocal;
      case 'presbyopia':
        return context.l10n.simCatPresbyopia;
      case 'polarized':
        return context.l10n.simCatPolarized;
      case 'anti_reflex':
        return context.l10n.simCatAntiReflective;
      case 'drive':
        return context.l10n.simCatDriveWear;
      case 'photochromic':
        return context.l10n.simCatPhotochromic;
      case 'solar':
        return context.l10n.simCatSolar;
      case 'tint':
        return context.l10n.simCatTint;
      case 'aspheric':
        return context.l10n.simCatAspheric;
      case 'blue_filter':
        return context.l10n.simCatBlueFilter;
      default:
        return category.displayName;
    }
  }

  static String categoryDescription(
    BuildContext context,
    SimulationCategory category,
  ) {
    switch (category.id) {
      case 'myopia':
        return context.l10n.simCatMyopiaDesc;
      case 'multifocal':
        return context.l10n.simCatMultifocalDesc;
      case 'bifocal':
        return context.l10n.simCatBifocalDesc;
      case 'presbyopia':
        return context.l10n.simCatPresbyopiaDesc;
      case 'polarized':
        return context.l10n.simCatPolarizedDesc;
      case 'anti_reflex':
        return context.l10n.simCatAntiReflectiveDesc;
      case 'drive':
        return context.l10n.simCatDriveWearDesc;
      case 'photochromic':
        return context.l10n.simCatPhotochromicDesc;
      case 'solar':
        return context.l10n.simCatSolarDesc;
      case 'tint':
        return context.l10n.simCatTintDesc;
      case 'aspheric':
        return context.l10n.simCatAsphericDesc;
      case 'blue_filter':
        return context.l10n.simCatBlueFilterDesc;
      default:
        return category.description;
    }
  }

  static String scenarioName(
    BuildContext context,
    SimulationScenario scenario,
  ) {
    switch (scenario.id) {
      case 'myopia_clothing':
        return context.l10n.simSceneClothingStore;
      case 'drive_driving_sunny':
        return context.l10n.simSceneDrivingSunny;
      case 'drive_driving_cloudy':
        return context.l10n.simSceneDrivingCloudy;
      case 'drive_golf_sunny':
        return context.l10n.simSceneGolfSunny;
      case 'drive_golf_cloudy':
        return context.l10n.simSceneGolfCloudy;
      case 'drive_beach_sunny':
        return context.l10n.simSceneBeachSunny;
      case 'drive_beach_cloudy':
        return context.l10n.simSceneBeachCloudy;
      case 'drive_moto_sunny':
        return context.l10n.simSceneMotorcycleSunny;
      case 'drive_moto_cloudy':
        return context.l10n.simSceneMotorcycleCloudy;
      case 'drive_tennis_sunny':
        return context.l10n.simSceneTennisSunny;
      case 'drive_tennis_cloudy':
        return context.l10n.simSceneTennisCloudy;
      case 'drive_yacht_sunny':
        return context.l10n.simSceneYachtSunny;
      case 'drive_yacht_cloudy':
        return context.l10n.simSceneYachtCloudy;
    }

    switch (scenario.sceneName) {
      case 'kitchen':
        return context.l10n.simSceneKitchen;
      case 'market':
        return context.l10n.simSceneMarket;
      case 'grocery':
        return context.l10n.simSceneGrocery;
      case 'clothing':
        return context.l10n.simSceneClothing;
      case 'office':
        return context.l10n.simSceneOffice;
      case 'driving':
        return context.l10n.simSceneDriving;
      case 'golf':
        return context.l10n.simSceneGolf;
      case 'beach':
        return context.l10n.simSceneBeach;
      case 'tennis':
        return context.l10n.simSceneTennis;
      case 'yacht':
        return context.l10n.simSceneYacht;
      case 'motorcycle':
        return context.l10n.simSceneMotorcycle;
      case 'baseball':
        return context.l10n.simSceneBaseball;
      case 'basketball':
        return context.l10n.simSceneBasketball;
      case 'soccer':
        return context.l10n.simSceneSoccer;
      case 'concert':
        return context.l10n.simSceneConcert;
      case 'bridge':
        return context.l10n.simSceneBridge;
      case 'building_positive':
        return context.l10n.simSceneBuildingPositive;
      case 'building_negative':
        return context.l10n.simSceneBuildingNegative;
      case 'text_positive':
        return context.l10n.simSceneTextPositive;
      case 'text_negative':
        return context.l10n.simSceneTextNegative;
      case 'beach2':
        return context.l10n.simSceneBeach2;
      case 'car':
        return context.l10n.simSceneCar;
      case 'optic':
        return context.l10n.simSceneOpticStore;
      case 'smartphone':
        return context.l10n.simSceneSmartphone;
      case 'store':
        return context.l10n.simSceneStore;
      default:
        return scenario.displayName;
    }
  }

  static String lensName(BuildContext context, CorrectionLens lens) {
    switch (lens.name) {
      case 'monofocal_near':
        return context.l10n.simLensMonofocalNear;
      case 'monofocal_far':
        return context.l10n.simLensMonofocalFar;
      case 'invisible':
        return context.l10n.simLensInvisibleBifocal;
      case 'multifocal':
        return context.l10n.simLensMultifocal;
      case 'anti_reflective':
        return context.l10n.simLensWithAR;
      case 'drivewear':
        return context.l10n.simCatDriveWear;
      case 'sin_lente':
        return context.l10n.simLensNoLens;
      case 'economic':
      case 'economico':
        return context.l10n.simQualityEconomy;
      case 'standard':
      case 'estandar':
        return context.l10n.simQualityStandard;
      case 'good':
      case 'bueno':
        return context.l10n.simQualityGood;
      case 'premium':
        return context.l10n.simQualityPremium;
      case 'aspheric':
        return context.l10n.simLensAspheric;
      case 'gray':
        return context.l10n.simColorGray;
      case 'brown':
        return context.l10n.simColorBrown;
      case 'green':
        return context.l10n.simColorGreen;
      case 'sunbalance':
        return context.l10n.simColorSunBalance;
      case 'yellow':
        return context.l10n.simColorYellow;
      case 'aqua':
        return context.l10n.simColorAqua;
      case 'blue':
        return context.l10n.simColorBlue;
      case 'orange':
        return context.l10n.simColorOrange;
      case 'red':
        return context.l10n.simColorRed;
      default:
        final diopterMatch = RegExp(r'^standard(_{1,2})(\d+)$').firstMatch(
          lens.name,
        );
        if (diopterMatch != null) {
          final sign = diopterMatch.group(1) == '__' ? '-' : '+';
          final value = diopterMatch.group(2);
          return '$sign$value.00 ${context.l10n.simQualityStandard}';
        }
        return lens.displayName;
    }
  }
}
