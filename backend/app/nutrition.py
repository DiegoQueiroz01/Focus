"""Cálculo da meta diária de calorias e macronutrientes.

Método (o mesmo usado pela maioria dos apps de dieta):
1. Gasto em repouso (TMB) pela equação de Mifflin-St Jeor (1990), a mais precisa para
   adultos segundo a Academy of Nutrition and Dietetics.
2. Gasto total (GET) = TMB × fator de atividade.
3. Meta = GET ± ajuste do objetivo. 1 kg de gordura corporal ≈ 7.700 kcal, então perder
   0,5 kg/semana pede ~550 kcal/dia a menos.
4. Proteína em g por kg (ISSN: 1,4–2,0 g/kg para quem treina; mais alta no déficit para
   preservar massa magra), gordura em 25% das calorias (mínimo 0,6 g/kg) e o restante
   em carboidratos. Fibras: 14 g a cada 1.000 kcal. Água: 35 ml por kg.
"""

from dataclasses import dataclass
from datetime import date
from enum import Enum

KCAL_POR_KG = 7700


class Sex(str, Enum):
    MALE = "male"
    FEMALE = "female"


class ActivityLevel(str, Enum):
    SEDENTARY = "sedentary"
    LIGHT = "light"
    MODERATE = "moderate"
    ACTIVE = "active"
    VERY_ACTIVE = "very_active"


ACTIVITY_FACTOR = {
    ActivityLevel.SEDENTARY: 1.2,
    ActivityLevel.LIGHT: 1.375,
    ActivityLevel.MODERATE: 1.55,
    ActivityLevel.ACTIVE: 1.725,
    ActivityLevel.VERY_ACTIVE: 1.9,
}


class Goal(str, Enum):
    LOSE = "lose"
    MAINTAIN = "maintain"
    GAIN = "gain"


class GoalPace(str, Enum):
    SLOW = "slow"
    MODERATE = "moderate"
    FAST = "fast"


# kg por semana. No ganho o ritmo é menor para que seja principalmente músculo.
WEEKLY_CHANGE_KG = {
    Goal.LOSE: {GoalPace.SLOW: 0.25, GoalPace.MODERATE: 0.5, GoalPace.FAST: 0.75},
    Goal.GAIN: {GoalPace.SLOW: 0.125, GoalPace.MODERATE: 0.25, GoalPace.FAST: 0.5},
}

PROTEIN_G_PER_KG = {Goal.LOSE: 2.0, Goal.MAINTAIN: 1.6, Goal.GAIN: 1.8}
FAT_SHARE = 0.25
FAT_MIN_G_PER_KG = 0.6

# Mínimos recomendados sem acompanhamento profissional.
MIN_CALORIES = {Sex.FEMALE: 1200, Sex.MALE: 1500}


class Meal(str, Enum):
    BREAKFAST = "breakfast"
    MORNING_SNACK = "morning_snack"
    LUNCH = "lunch"
    AFTERNOON_SNACK = "afternoon_snack"
    DINNER = "dinner"
    SUPPER = "supper"


@dataclass(frozen=True)
class NutritionPlan:
    bmr: int
    tdee: int
    calories: int
    protein_g: int
    carbs_g: int
    fat_g: int
    fiber_g: int
    water_ml: int
    bmi: float
    # Diferença em relação ao gasto total (negativa = déficit).
    adjustment_kcal: int
    weekly_change_kg: float
    # True quando a meta foi elevada até o mínimo seguro.
    limited_by_minimum: bool
    # True quando o usuário definiu as calorias manualmente.
    custom_calories: bool


def age_on(birth_date: date, today: date) -> int:
    before_birthday = (today.month, today.day) < (birth_date.month, birth_date.day)
    return today.year - birth_date.year - int(before_birthday)


def bmr_mifflin(sex: Sex, weight_kg: float, height_cm: float, age: int) -> float:
    base = 10 * weight_kg + 6.25 * height_cm - 5 * age
    return base + 5 if sex == Sex.MALE else base - 161


def _round10(value: float) -> int:
    return int(round(value / 10) * 10)


def compute_plan(
    *,
    sex: Sex,
    age: int,
    height_cm: float,
    weight_kg: float,
    activity: ActivityLevel,
    goal: Goal,
    pace: GoalPace | None = None,
    calorie_override: int | None = None,
) -> NutritionPlan:
    bmr = bmr_mifflin(sex, weight_kg, height_cm, age)
    tdee = bmr * ACTIVITY_FACTOR[activity]
    height_m = height_cm / 100
    bmi = weight_kg / (height_m**2)

    weekly = 0.0
    if goal != Goal.MAINTAIN:
        weekly = WEEKLY_CHANGE_KG[goal][pace or GoalPace.MODERATE]
    adjustment = weekly * KCAL_POR_KG / 7
    target = tdee - adjustment if goal == Goal.LOSE else tdee + adjustment

    limited = False
    if calorie_override:
        target = calorie_override
    elif goal == Goal.LOSE:
        floor = max(MIN_CALORIES[sex], bmr)
        if target < floor:
            target, limited = floor, True
    calories = _round10(target)

    # Em quem tem obesidade, a proteína pelo peso total sairia alta demais; usa-se o peso
    # equivalente a IMC 27 como referência.
    reference_kg = min(weight_kg, 27 * height_m**2)
    protein = PROTEIN_G_PER_KG[goal] * reference_kg
    fat = max(calories * FAT_SHARE / 9, FAT_MIN_G_PER_KG * reference_kg)
    carbs = max((calories - protein * 4 - fat * 9) / 4, 0)

    # Ao manter o peso, a diferença é só o arredondamento da meta.
    keeps_weight = goal == Goal.MAINTAIN and not calorie_override
    delta = 0 if keeps_weight else calories - tdee
    effective_weekly = delta * 7 / KCAL_POR_KG
    return NutritionPlan(
        bmr=round(bmr),
        tdee=round(tdee),
        calories=calories,
        protein_g=round(protein),
        carbs_g=round(carbs),
        fat_g=round(fat),
        fiber_g=max(25, round(calories / 1000 * 14)),
        water_ml=int(round(weight_kg * 35, -1)),
        bmi=round(bmi, 1),
        adjustment_kcal=round(delta),
        weekly_change_kg=round(effective_weekly, 2),
        limited_by_minimum=limited,
        custom_calories=bool(calorie_override),
    )
