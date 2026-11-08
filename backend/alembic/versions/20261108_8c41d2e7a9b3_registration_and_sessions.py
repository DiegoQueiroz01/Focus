"""cadastro por e-mail, grupo muscular e sessões de treino

- users: nome e e-mail (username passa a ser opcional, só para contas antigas)
- exercises: grupo muscular
- workouts vira um plano de treino; cada execução fica em workout_sessions
- treinos já registrados são convertidos em sessões concluídas

Revision ID: 8c41d2e7a9b3
Revises: 257d12a3e56c
Create Date: 2026-11-08 10:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "8c41d2e7a9b3"
down_revision: str | None = "257d12a3e56c"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # --- users
    op.add_column("users", sa.Column("name", sa.String(length=80), server_default="", nullable=False))
    op.add_column("users", sa.Column("email", sa.String(length=254), nullable=True))
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.alter_column("users", "username", existing_type=sa.String(length=50), nullable=True)
    op.execute("UPDATE users SET name = username WHERE name = ''")

    # --- exercises
    op.add_column(
        "exercises",
        sa.Column("muscle_group", sa.String(length=30), server_default="other", nullable=False),
    )

    # --- workout_sessions
    op.create_table(
        "workout_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("workout_id", sa.Integer(), nullable=True),
        sa.Column("workout_name", sa.String(length=120), nullable=False),
        sa.Column("workout_type", sa.String(length=30), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("total_volume_kg", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("total_sets", sa.Integer(), nullable=False),
        sa.Column("last_muscle_group", sa.String(length=30), nullable=True),
        sa.CheckConstraint("duration_seconds >= 0", name=op.f("ck_workout_sessions_duration_non_negative")),
        sa.CheckConstraint("total_sets >= 0", name=op.f("ck_workout_sessions_sets_non_negative")),
        sa.CheckConstraint("total_volume_kg >= 0", name=op.f("ck_workout_sessions_volume_non_negative")),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_workout_sessions_user_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["workout_id"],
            ["workouts.id"],
            name=op.f("fk_workout_sessions_workout_id_workouts"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_workout_sessions")),
    )
    op.create_index(
        "ix_workout_sessions_user_id_started_at", "workout_sessions", ["user_id", "started_at"]
    )
    op.create_index(op.f("ix_workout_sessions_workout_id"), "workout_sessions", ["workout_id"])

    # Cada treino registrado até aqui vira uma sessão concluída, preservando o histórico.
    op.execute(
        """
        INSERT INTO workout_sessions (
            user_id, workout_id, workout_name, workout_type, started_at, finished_at,
            duration_seconds, total_volume_kg, total_sets
        )
        SELECT
            w.user_id, w.id, w.name, w.type, w.performed_at,
            w.performed_at + make_interval(mins => w.duration_minutes),
            w.duration_minutes * 60,
            COALESCE(SUM(e.sets * e.reps * e.weight_kg), 0),
            COALESCE(SUM(e.sets), 0)
        FROM workouts w
        LEFT JOIN exercises e ON e.workout_id = w.id
        GROUP BY w.id
        """
    )

    # --- workouts deixa de guardar data e duração (agora vêm das sessões)
    op.drop_index("ix_workouts_user_id_performed_at", table_name="workouts")
    op.drop_constraint(op.f("ck_workouts_duration_non_negative"), "workouts", type_="check")
    op.drop_column("workouts", "performed_at")
    op.drop_column("workouts", "duration_minutes")
    op.create_index(op.f("ix_workouts_user_id"), "workouts", ["user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_workouts_user_id"), table_name="workouts")
    op.add_column(
        "workouts",
        sa.Column("duration_minutes", sa.Integer(), server_default="0", nullable=False),
    )
    op.add_column("workouts", sa.Column("performed_at", sa.DateTime(timezone=True), nullable=True))
    op.execute(
        """
        UPDATE workouts w SET
            performed_at = COALESCE(
                (SELECT MAX(s.started_at) FROM workout_sessions s WHERE s.workout_id = w.id),
                w.created_at
            ),
            duration_minutes = COALESCE(
                (SELECT MAX(s.duration_seconds) / 60 FROM workout_sessions s WHERE s.workout_id = w.id),
                0
            )
        """
    )
    op.alter_column("workouts", "performed_at", nullable=False)
    op.create_check_constraint(
        op.f("ck_workouts_duration_non_negative"), "workouts", "duration_minutes >= 0"
    )
    op.create_index("ix_workouts_user_id_performed_at", "workouts", ["user_id", "performed_at"])

    op.drop_index(op.f("ix_workout_sessions_workout_id"), table_name="workout_sessions")
    op.drop_index("ix_workout_sessions_user_id_started_at", table_name="workout_sessions")
    op.drop_table("workout_sessions")

    op.drop_column("exercises", "muscle_group")

    # Contas criadas pelo cadastro não têm username; usa o e-mail no lugar.
    op.execute("UPDATE users SET username = LEFT(email, 50) WHERE username IS NULL")
    op.alter_column("users", "username", existing_type=sa.String(length=50), nullable=False)
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_column("users", "email")
    op.drop_column("users", "name")
