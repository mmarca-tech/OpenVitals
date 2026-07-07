import 'package:flutter/material.dart';

import '../../core/presentation/display_value.dart';
import '../../core/presentation/unit_formatter.dart';
import '../../domain/model/nutrition_models.dart';
import '../../ui/theme/app_colors.dart';

/// Per-nutrient presentation helpers, ported from the Kotlin
/// `NutritionFormatting`.

const Color _proteinColor = Color(0xFF7E57C2);
const Color _carbsColor = Color(0xFF26A69A);
const Color _fatColor = Color(0xFFFFB300);
const Color _vitaminColor = Color(0xFF5E7CE2);
const Color _mineralColor = Color(0xFF8D6E63);
const Color _otherColor = Color(0xFF00897B);

/// Formats [value] for [nutrient] using its unit (energy / mass grams /
/// adaptive mass), mirroring the Kotlin `NutritionNutrient.displayValue`.
DisplayValue nutrientDisplayValue(
  NutritionNutrient nutrient,
  double value,
  UnitFormatter formatter,
) {
  switch (nutrient.unit) {
    case NutritionNutrientUnit.energyKcal:
      return formatter.energy(value);
    case NutritionNutrientUnit.massGrams:
      return DisplayValue(formatter.count(value.round()), 'g');
    case NutritionNutrientUnit.massAdaptive:
      return _adaptiveMassDisplay(value, formatter);
  }
}

DisplayValue _adaptiveMassDisplay(double grams, UnitFormatter formatter) {
  final milligrams = grams * 1000.0;
  final micrograms = grams * 1000000.0;
  if (grams >= 1.0) {
    return DisplayValue(formatter.decimal(grams, grams < 10.0 ? 1 : 0), 'g');
  }
  if (milligrams >= 1.0) {
    return DisplayValue(
      formatter.decimal(milligrams, milligrams < 10.0 ? 1 : 0),
      'mg',
    );
  }
  return DisplayValue(
    formatter.decimal(micrograms, micrograms < 10.0 ? 1 : 0),
    'mcg',
  );
}

/// The accent colour for [nutrient], mirroring the Kotlin
/// `NutritionNutrient.color`.
Color nutrientColor(NutritionNutrient nutrient) {
  switch (nutrient.group) {
    case NutritionNutrientGroup.overview:
      switch (nutrient) {
        case NutritionNutrient.energy:
          return AppColors.nutrition;
        case NutritionNutrient.protein:
          return _proteinColor;
        case NutritionNutrient.totalCarbohydrate:
          return _carbsColor;
        case NutritionNutrient.totalFat:
          return _fatColor;
        default:
          return AppColors.nutrition;
      }
    case NutritionNutrientGroup.carbohydrates:
      return _carbsColor;
    case NutritionNutrientGroup.fats:
      return _fatColor;
    case NutritionNutrientGroup.vitamins:
      return _vitaminColor;
    case NutritionNutrientGroup.minerals:
      return _mineralColor;
    case NutritionNutrientGroup.other:
      return _otherColor;
  }
}

/// The display title for [group], mirroring the Kotlin
/// `NutritionNutrientGroup.titleRes`.
String nutrientGroupTitle(NutritionNutrientGroup group) {
  switch (group) {
    case NutritionNutrientGroup.overview:
      return 'Nutrition';
    case NutritionNutrientGroup.carbohydrates:
      return 'Carbohydrates';
    case NutritionNutrientGroup.fats:
      return 'Fats';
    case NutritionNutrientGroup.vitamins:
      return 'Vitamins';
    case NutritionNutrientGroup.minerals:
      return 'Minerals';
    case NutritionNutrientGroup.other:
      return 'Other nutrients';
  }
}

/// The display title for [nutrient], mirroring the Kotlin
/// `NutritionNutrient.titleRes` (English strings).
String nutrientTitle(NutritionNutrient nutrient) {
  switch (nutrient) {
    case NutritionNutrient.energy:
      return 'Calories in';
    case NutritionNutrient.protein:
      return 'Protein';
    case NutritionNutrient.totalCarbohydrate:
      return 'Carbs';
    case NutritionNutrient.totalFat:
      return 'Fat';
    case NutritionNutrient.dietaryFiber:
      return 'Dietary fiber';
    case NutritionNutrient.sugar:
      return 'Sugar';
    case NutritionNutrient.energyFromFat:
      return 'Energy from fat';
    case NutritionNutrient.monounsaturatedFat:
      return 'Monounsaturated fat';
    case NutritionNutrient.polyunsaturatedFat:
      return 'Polyunsaturated fat';
    case NutritionNutrient.saturatedFat:
      return 'Saturated fat';
    case NutritionNutrient.transFat:
      return 'Trans fat';
    case NutritionNutrient.unsaturatedFat:
      return 'Unsaturated fat';
    case NutritionNutrient.cholesterol:
      return 'Cholesterol';
    case NutritionNutrient.biotin:
      return 'Biotin';
    case NutritionNutrient.folate:
      return 'Folate';
    case NutritionNutrient.folicAcid:
      return 'Folic acid';
    case NutritionNutrient.niacin:
      return 'Niacin';
    case NutritionNutrient.pantothenicAcid:
      return 'Pantothenic acid';
    case NutritionNutrient.riboflavin:
      return 'Riboflavin';
    case NutritionNutrient.thiamin:
      return 'Thiamin';
    case NutritionNutrient.vitaminA:
      return 'Vitamin A';
    case NutritionNutrient.vitaminB12:
      return 'Vitamin B12';
    case NutritionNutrient.vitaminB6:
      return 'Vitamin B6';
    case NutritionNutrient.vitaminC:
      return 'Vitamin C';
    case NutritionNutrient.vitaminD:
      return 'Vitamin D';
    case NutritionNutrient.vitaminE:
      return 'Vitamin E';
    case NutritionNutrient.vitaminK:
      return 'Vitamin K';
    case NutritionNutrient.calcium:
      return 'Calcium';
    case NutritionNutrient.chloride:
      return 'Chloride';
    case NutritionNutrient.chromium:
      return 'Chromium';
    case NutritionNutrient.copper:
      return 'Copper';
    case NutritionNutrient.iodine:
      return 'Iodine';
    case NutritionNutrient.iron:
      return 'Iron';
    case NutritionNutrient.magnesium:
      return 'Magnesium';
    case NutritionNutrient.manganese:
      return 'Manganese';
    case NutritionNutrient.molybdenum:
      return 'Molybdenum';
    case NutritionNutrient.phosphorus:
      return 'Phosphorus';
    case NutritionNutrient.potassium:
      return 'Potassium';
    case NutritionNutrient.selenium:
      return 'Selenium';
    case NutritionNutrient.sodium:
      return 'Sodium';
    case NutritionNutrient.zinc:
      return 'Zinc';
    case NutritionNutrient.caffeine:
      return 'Caffeine';
  }
}
