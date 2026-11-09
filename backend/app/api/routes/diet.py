import datetime as dt
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import CurrentUser, DbSession
from app.foods import foods_by_id, matches, normalize, search_foods
from app.models import CustomFood, FoodEntry, User, WeightEntry
from app.nutrition import ActivityLevel, Goal, GoalPace, Meal, Sex, age_on, compute_plan
from app.schemas.diet import (
    CustomFoodCreate,
    DaySummary,
    DietDay,
    FoodEntryCreate,
    FoodEntryRead,
    FoodEntryUpdate,
    FoodRead,
    MealRead,
    PlanRead,
    PortionRead,
    ProfileRead,
    ProfileUpdate,
    Totals,
    WeightCreate,
    WeightRead,
)

router = APIRouter(tags=["diet"])

CUSTOM_PREFIX = "custom:"


# --- Peso atual (usado também pelo GPS)


def latest_weight(db: Session, user_id: int) -> WeightEntry | None:
    return db.scalar(
        select(WeightEntry)
        .where(WeightEntry.user_id == user_id)
        .order_by(WeightEntry.date.desc(), WeightEntry.id.desc())
        .limit(1)
    )


def _upsert_weight(db: Session, user: User, day: dt.date, weight_kg: float) -> WeightEntry:
    entry = db.scalar(
        select(WeightEntry).where(WeightEntry.user_id == user.id, WeightEntry.date == day)
    )
    if entry is None:
        entry = WeightEntry(user_id=user.id, date=day, weight_kg=weight_kg)
        db.add(entry)
    else:
        entry.weight_kg = weight_kg
    return entry


# --- Perfil e meta


def _plan_for(user: User, weight: WeightEntry | None) -> PlanRead | None:
    if None in (user.sex, user.birth_date, user.height_cm, user.activity_level, user.goal) or weight is None:
        return None
    goal = Goal(user.goal)
    plan = compute_plan(
        sex=Sex(user.sex),
        age=age_on(user.birth_date, dt.date.today()),
        height_cm=user.height_cm,
        weight_kg=weight.weight_kg,
        activity=ActivityLevel(user.activity_level),
        goal=goal,
        pace=GoalPace(user.goal_pace) if user.goal_pace else None,
        calorie_override=user.calorie_override,
    )

    weeks = None
    target = user.target_weight_kg
    if target and plan.weekly_change_kg:
        remaining = target - weight.weight_kg
        # Só faz sentido se o ritmo aponta na direção do peso desejado.
        if remaining * plan.weekly_change_kg > 0:
            weeks = max(1, round(remaining / plan.weekly_change_kg))
    return PlanRead(**plan.__dict__, weeks_to_target=weeks)


def _profile(db: Session, user: User) -> ProfileRead:
    weight = latest_weight(db, user.id)
    plan = _plan_for(user, weight)
    return ProfileRead(
        sex=user.sex,
        birth_date=user.birth_date,
        age=age_on(user.birth_date, dt.date.today()) if user.birth_date else None,
        height_cm=user.height_cm,
        activity_level=user.activity_level,
        goal=user.goal,
        goal_pace=user.goal_pace,
        target_weight_kg=user.target_weight_kg,
        calorie_override=user.calorie_override,
        weight_kg=weight.weight_kg if weight else None,
        weight_date=weight.date if weight else None,
        complete=plan is not None,
        plan=plan,
    )


@router.get("/profile", response_model=ProfileRead)
def get_profile(user: CurrentUser, db: DbSession) -> ProfileRead:
    return _profile(db, user)


@router.put("/profile", response_model=ProfileRead)
def update_profile(payload: ProfileUpdate, user: CurrentUser, db: DbSession) -> ProfileRead:
    user.sex = payload.sex.value
    user.birth_date = payload.birth_date
    user.height_cm = payload.height_cm
    user.activity_level = payload.activity_level.value
    user.goal = payload.goal.value
    user.goal_pace = payload.goal_pace.value if payload.goal_pace else None
    user.target_weight_kg = payload.target_weight_kg
    user.calorie_override = payload.calorie_override
    if payload.weight_kg is not None:
        _upsert_weight(db, user, payload.weight_date or dt.date.today(), payload.weight_kg)
    elif latest_weight(db, user.id) is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Informe seu peso atual.")
    db.commit()
    return _profile(db, user)


# --- Histórico de peso


@router.get("/weights", response_model=list[WeightRead])
def list_weights(
    user: CurrentUser, db: DbSession, limit: Annotated[int, Query(ge=1, le=400)] = 90
) -> list[WeightEntry]:
    query = (
        select(WeightEntry)
        .where(WeightEntry.user_id == user.id)
        .order_by(WeightEntry.date.desc())
        .limit(limit)
    )
    return list(db.scalars(query).all())


@router.post("/weights", response_model=WeightRead, status_code=status.HTTP_201_CREATED)
def add_weight(payload: WeightCreate, user: CurrentUser, db: DbSession) -> WeightEntry:
    entry = _upsert_weight(db, user, payload.date, payload.weight_kg)
    db.commit()
    return entry


@router.delete("/weights/{weight_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_weight(weight_id: int, user: CurrentUser, db: DbSession) -> Response:
    entry = db.scalar(
        select(WeightEntry).where(WeightEntry.id == weight_id, WeightEntry.user_id == user.id)
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro não encontrado")
    db.delete(entry)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# --- Alimentos


def _food_read_from_base(food_id: str) -> FoodRead | None:
    food = foods_by_id().get(food_id)
    if food is None:
        return None
    return FoodRead(
        id=food.id,
        name=food.name,
        category=food.category,
        source=food.id.split(":")[0],
        kcal=food.kcal,
        protein=food.protein,
        carbs=food.carbs,
        fat=food.fat,
        fiber=food.fiber,
        portions=[PortionRead(label=p.label, grams=p.grams) for p in food.portions],
    )


def _food_read_from_custom(food: CustomFood) -> FoodRead:
    portions = []
    if food.serving_grams:
        portions.append(PortionRead(label=food.serving_label or "1 porção", grams=food.serving_grams))
    return FoodRead(
        id=f"{CUSTOM_PREFIX}{food.id}",
        name=food.name,
        category="Meus alimentos",
        source="custom",
        kcal=food.kcal,
        protein=food.protein,
        carbs=food.carbs,
        fat=food.fat,
        fiber=food.fiber,
        portions=portions,
    )


def _find_food(db: Session, user: User, food_id: str) -> FoodRead | None:
    if food_id.startswith(CUSTOM_PREFIX):
        raw_id = food_id.removeprefix(CUSTOM_PREFIX)
        if not raw_id.isdigit():
            return None
        custom = db.scalar(
            select(CustomFood).where(CustomFood.id == int(raw_id), CustomFood.user_id == user.id)
        )
        return _food_read_from_custom(custom) if custom else None
    return _food_read_from_base(food_id)


@router.get("/foods", response_model=list[FoodRead])
def list_foods(
    user: CurrentUser,
    db: DbSession,
    q: Annotated[str | None, Query(max_length=80, description="Busca sem acento por partes do nome")] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> list[FoodRead]:
    """Com `q`: alimentos do usuário que casam primeiro, depois a base TACO.
    Sem `q`: os alimentos usados recentemente."""
    terms = normalize(q or "").split()
    if terms:
        customs = db.scalars(select(CustomFood).where(CustomFood.user_id == user.id)).all()
        mine = [_food_read_from_custom(c) for c in customs if matches(normalize(c.name), terms)]
        base = [_food_read_from_base(f.id) for f in search_foods(q or "", limit)]
        return (mine + base)[:limit]

    recent_ids = db.execute(
        select(FoodEntry.food_id, func.max(FoodEntry.id).label("last"))
        .where(FoodEntry.user_id == user.id)
        .group_by(FoodEntry.food_id)
        .order_by(func.max(FoodEntry.id).desc())
        .limit(limit)
    ).all()
    found = [_find_food(db, user, row.food_id) for row in recent_ids]
    return [f for f in found if f is not None]


@router.get("/foods/custom", response_model=list[FoodRead])
def list_custom_foods(user: CurrentUser, db: DbSession) -> list[FoodRead]:
    customs = db.scalars(
        select(CustomFood).where(CustomFood.user_id == user.id).order_by(CustomFood.name)
    ).all()
    return [_food_read_from_custom(c) for c in customs]


@router.post("/foods/custom", response_model=FoodRead, status_code=status.HTTP_201_CREATED)
def create_custom_food(payload: CustomFoodCreate, user: CurrentUser, db: DbSession) -> FoodRead:
    per100 = 100 / payload.serving_grams
    food = CustomFood(
        user_id=user.id,
        name=payload.name,
        kcal=round(payload.kcal * per100, 1),
        protein=round(payload.protein * per100, 1),
        carbs=round(payload.carbs * per100, 1),
        fat=round(payload.fat * per100, 1),
        fiber=round(payload.fiber * per100, 1),
        serving_label=payload.serving_label,
        serving_grams=payload.serving_grams,
    )
    db.add(food)
    db.commit()
    return _food_read_from_custom(food)


@router.delete("/foods/custom/{food_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_custom_food(food_id: int, user: CurrentUser, db: DbSession) -> Response:
    food = db.scalar(select(CustomFood).where(CustomFood.id == food_id, CustomFood.user_id == user.id))
    if food is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alimento não encontrado")
    # O que já foi registrado continua no diário (os valores ficam copiados no registro).
    db.delete(food)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/foods/{food_id}", response_model=FoodRead)
def get_food(food_id: str, user: CurrentUser, db: DbSession) -> FoodRead:
    food = _find_food(db, user, food_id)
    if food is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alimento não encontrado")
    return food


# --- Diário alimentar


def _entry_totals(entry: FoodEntry) -> Totals:
    f = entry.grams / 100
    return Totals(
        kcal=entry.kcal_100g * f,
        protein=entry.protein_100g * f,
        carbs=entry.carbs_100g * f,
        fat=entry.fat_100g * f,
        fiber=entry.fiber_100g * f,
    )


def _get_entry(db: Session, user: User, entry_id: int) -> FoodEntry:
    entry = db.scalar(select(FoodEntry).where(FoodEntry.id == entry_id, FoodEntry.user_id == user.id))
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro não encontrado")
    return entry


@router.get("/diet/days/{day}", response_model=DietDay)
def get_day(day: dt.date, user: CurrentUser, db: DbSession) -> DietDay:
    entries = db.scalars(
        select(FoodEntry)
        .where(FoodEntry.user_id == user.id, FoodEntry.date == day)
        .order_by(FoodEntry.id)
    ).all()

    day_totals = Totals()
    meals = []
    for meal in Meal:
        meal_entries = [e for e in entries if e.meal == meal.value]
        meal_totals = Totals()
        for entry in meal_entries:
            meal_totals.add(_entry_totals(entry))
        day_totals.add(meal_totals)
        meals.append(
            MealRead(
                meal=meal,
                totals=meal_totals.rounded(),
                entries=[FoodEntryRead.model_validate(e) for e in meal_entries],
            )
        )

    return DietDay(
        date=day,
        plan=_plan_for(user, latest_weight(db, user.id)),
        totals=day_totals.rounded(),
        meals=meals,
    )


@router.get("/diet/summary", response_model=list[DaySummary])
def get_summary(
    user: CurrentUser,
    db: DbSession,
    start: Annotated[dt.date, Query()],
    end: Annotated[dt.date, Query(description="Inclusivo")],
) -> list[DaySummary]:
    """Totais por dia no intervalo (só os dias com registro)."""
    if (end - start).days > 400:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Intervalo muito grande")
    entries = db.scalars(
        select(FoodEntry).where(
            FoodEntry.user_id == user.id, FoodEntry.date >= start, FoodEntry.date <= end
        )
    ).all()
    per_day: dict[dt.date, Totals] = {}
    for entry in entries:
        per_day.setdefault(entry.date, Totals()).add(_entry_totals(entry))
    return [
        DaySummary(date=day, kcal=round(t.kcal), protein=round(t.protein, 1), carbs=round(t.carbs, 1), fat=round(t.fat, 1))
        for day, t in sorted(per_day.items())
    ]


@router.post("/diet/entries", response_model=FoodEntryRead, status_code=status.HTTP_201_CREATED)
def add_entry(payload: FoodEntryCreate, user: CurrentUser, db: DbSession) -> FoodEntry:
    food = _find_food(db, user, payload.food_id)
    if food is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Alimento não encontrado")
    entry = FoodEntry(
        user_id=user.id,
        date=payload.date,
        meal=payload.meal.value,
        food_id=food.id,
        name=food.name,
        grams=payload.grams,
        portion_label=payload.portion_label,
        kcal_100g=food.kcal,
        protein_100g=food.protein,
        carbs_100g=food.carbs,
        fat_100g=food.fat,
        fiber_100g=food.fiber,
    )
    db.add(entry)
    db.commit()
    return entry


@router.put("/diet/entries/{entry_id}", response_model=FoodEntryRead)
def update_entry(entry_id: int, payload: FoodEntryUpdate, user: CurrentUser, db: DbSession) -> FoodEntry:
    entry = _get_entry(db, user, entry_id)
    if payload.meal is not None:
        entry.meal = payload.meal.value
    if payload.grams is not None:
        entry.grams = payload.grams
        entry.portion_label = payload.portion_label
    db.commit()
    return entry


@router.delete("/diet/entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(entry_id: int, user: CurrentUser, db: DbSession) -> Response:
    db.delete(_get_entry(db, user, entry_id))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
