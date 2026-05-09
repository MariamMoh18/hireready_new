"""add report fields (WPM, filler_count, voice_tone, facial_expression, content_quality)

Revision ID: c4d5e6f7g8h9
Revises: f3b9d4a8c1e2
Create Date: 2026-05-09 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c4d5e6f7g8h9'
down_revision = 'f3b9d4a8c1e2'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('answer', schema=None) as batch_op:
        batch_op.add_column(sa.Column('words_per_minute', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('filler_count', sa.Integer(), nullable=True))

    with op.batch_alter_table('score', schema=None) as batch_op:
        batch_op.add_column(sa.Column('voice_tone_score', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('facial_expression_score', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('content_quality_score', sa.Float(), nullable=True))


def downgrade():
    with op.batch_alter_table('score', schema=None) as batch_op:
        batch_op.drop_column('content_quality_score')
        batch_op.drop_column('facial_expression_score')
        batch_op.drop_column('voice_tone_score')

    with op.batch_alter_table('answer', schema=None) as batch_op:
        batch_op.drop_column('filler_count')
        batch_op.drop_column('words_per_minute')
