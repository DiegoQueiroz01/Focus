import datetime as dt

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator, model_validator

from app.nutrition import ActivityLevel, Goal, GoalPace, Meal, Sex


def _clean_name(value: str) -> str:
    value = " ".join(value.split())
    if not value:
        raise ValueError("Informe o nome")
    return value


# --- Perfil e meta


class ProfileUpdate(BaseModel):
    sex: Sex
    birth_date: dt.date
    height_cm: float = Field(ge=100, le=250)
    activity_level: ActivityLevel
    goal: Goal
    goal_pace: GoalPace | None = None
    target_weight_kg: float | None = Field(default=None, ge=30, le=300)
    calorie_override: int | None = Field(default=None, ge=800, le=6000)
    # Se vier, registra o peso do dia (data local do aparelho).
    weight_kg: float | None = Field(default=None, ge=30, le=300)
    weight_date: dt.date | None = None

    @field_validator("birth_date")
    @classmethod
    def _adult_age(cls, value: dt.date) -> dt.date:
        today = dt.date.today()
        age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
        if not 13 <= age <= 100:
            raise ValueError("idade deve estar entre 13 e 100 anos")
        return value

    @model_validator(mode="after")
    def _pace_when_changing(self) -> "ProfileUpdate":
        if self.goal == Goal.MAINTAIN:
            self.goal_pace = None
        elif self.goal_pace is None:
            self.goal_pace = GoalPace.MODERATE
        return self


class PlanRead(BaseModel):
    bmr: int
    tdee: int
    calories: int
    protein_g: int
    carbs_g: int
    fat_g: int
    fiber_g: int
    water_ml: int
    bmi: float
    adjustment_kcal: int
    weekly_change_kg: float
    limited_by_minimum: bool
    custom_calories: bool
    # Semanas estimadas até o peso desejado, quando há um e o objetivo aponta para ele.
    weeks_to_target: int | None = None


class ProfileRead(BaseModel):
    sex: Sex | None
    birth_date: dt.date | None
    age: int | None
    height_cm: float | None
    activity_level: ActivityLevel | None
    goal: Goal | None
    goal_pace: GoalPace | None
    target_weight_kg: float | None
    calorie_override: int | None
    weight_kg: float | None
    weight_date: dt.date | None
    # Falso enquanto o questionário não foi respondido.
    complete: bool
    plan: PlanRead | None


# --- Peso


class WeightCreate(BaseModel):
    date: dt.date
    weight_kg: float = Field(ge=30, le=300)


class WeightRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: dt.date
    weight_kg: float


# --- Alimentos


class PortionRead(BaseModel):
    label: str
    grams: float


class FoodRead(BaseModel):
    id: str
    name: str
    category: str
    # "taco", "extra" ou "custom" (cadastrado pelo usuário).
    source: str
    kcal: float
    protein: float
    carbs: float
    fat: float
    fiber: float
    portions: list[PortionRead]


class CustomFoodCreate(BaseModel):
    """Valores como estão no rótulo: referentes a uma porção de `serving_grams`."""

    name: str = Field(min_length=1, max_length=120)
    serving_grams: float = Field(gt=0, le=5000)
    serving_label: str | None = Field(default=None, max_length=60)
    kcal: float = Field(ge=0, le=10000)
    protein: float = Field(default=0, ge=0, le=1000)
    carbs: float = Field(default=0, ge=0, le=1000)
    fat: float = Field(default=0, ge=0, le=1000)
    fiber: float = Field(default=0, ge=0, le=1000)

    _name = field_validator("name")(_clean_name)

    @field_validator("serving_label")
    @classmethod
    def _label(cls, value: str | None) -> str | None:
        return " ".join((value or "").split()) or None


# --- Diário


class FoodEntryCreate(BaseModel):
    date: dt.date
    meal: Meal
    food_id: str = Field(min_length=1, max_length=40)
    grams: float = Field(gt=0, le=5000)
    portion_label: str | None = Field(default=None, max_length=60)


class FoodEntryUpdate(BaseModel):
    meal: Meal | None = None
    grams: float | None = Field(default=None, gt=0, le=5000)
    portion_label: str | None = Field(default=None, max_length=60)


class Totals(BaseModel):
    kcal: float = 0
    protein: float = 0
    carbs: float = 0
    fat: float = 0
    fiber: float = 0

    def add(self, other: "Totals") -> None:
        self.kcal += other.kcal
        self.protein += other.protein
        self.carbs += other.carbs
        self.fat += other.fat
        self.fiber += other.fiber

    def rounded(self) -> "Totals":
        return Totals(
            kcal=round(self.kcal),
            protein=round(self.protein, 1),
            carbs=round(self.carbs, 1),
            fat=round(self.fat, 1),
            fiber=round(self.fiber, 1),
        )


class FoodEntryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: dt.date
    meal: Meal
    food_id: str
    name: str
    grams: float
    portion_label: str | None
    kcal_100g: float = Field(exclude=True)
    protein_100g: float = Field(exclude=True)
    carbs_100g: float = Field(exclude=True)
    fat_100g: float = Field(exclude=True)
    fiber_100g: float = Field(exclude=True)

    @computed_field
    @property
    def totals(self) -> Totals:
        f = self.grams / 100
        return Totals(
            kcal=self.kcal_100g * f,
            protein=self.protein_100g * f,
            carbs=self.carbs_100g * f,
            fat=self.fat_100g * f,
            fiber=self.fiber_100g * f,
        ).rounded()


class MealRead(BaseModel):
    meal: Meal
    totals: Totals
    entries: list[FoodEntryRead]


class DietDay(BaseModel):
    date: dt.date
    plan: PlanRead | None
    totals: Totals
    meals: list[MealRead]


class DaySummary(BaseModel):
    date: dt.date
    kcal: float
    protein: float
    carbs: float
    fat: float
