"""add job_field and target_role to user

Revision ID: a4b2c6d8e0f2
Revises: f3b9d4a8c1e2
Create Date: 2026-05-11 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a4b2c6d8e0f2'
down_revision = 'c4d5e6f7g8h9'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('user', schema=None) as batch_op:
        batch_op.add_column(sa.Column('job_field', sa.String(length=120), nullable=True))
        batch_op.add_column(sa.Column('target_role', sa.String(length=120), nullable=True))


def downgrade():
    with op.batch_alter_table('user', schema=None) as batch_op:
        batch_op.drop_column('target_role')
        batch_op.drop_column('job_field')
