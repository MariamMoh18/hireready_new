"""add behavioral metric chunks

Revision ID: f3b9d4a8c1e2
Revises: b0a148b0cdc6
Create Date: 2026-05-07 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f3b9d4a8c1e2'
down_revision = 'b0a148b0cdc6'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'behavioral_metric_chunk',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('answer_id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=True),
        sa.Column('chunk_index', sa.Integer(), nullable=False),
        sa.Column('chunk_path', sa.String(length=500), nullable=True),
        sa.Column('chunk_start_ms', sa.Integer(), nullable=True),
        sa.Column('chunk_end_ms', sa.Integer(), nullable=True),
        sa.Column('transcript_text', sa.Text(), nullable=True),
        sa.Column('transcript_language', sa.String(length=32), nullable=True),
        sa.Column('audio_metrics', sa.JSON(), nullable=True),
        sa.Column('video_metrics', sa.JSON(), nullable=True),
        sa.Column('confidence_score', sa.Float(), nullable=True),
        sa.Column('stress_level', sa.Float(), nullable=True),
        sa.Column('eye_contact_score', sa.Float(), nullable=True),
        sa.Column('engagement_score', sa.Float(), nullable=True),
        sa.Column('is_final_chunk', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['answer_id'], ['answer.id']),
        sa.ForeignKeyConstraint(['question_id'], ['interview_question.id']),
        sa.ForeignKeyConstraint(['session_id'], ['interview_session.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('behavioral_metric_chunk', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_behavioral_metric_chunk_answer_id'), ['answer_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_behavioral_metric_chunk_question_id'), ['question_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_behavioral_metric_chunk_session_id'), ['session_id'], unique=False)


def downgrade():
    with op.batch_alter_table('behavioral_metric_chunk', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_behavioral_metric_chunk_session_id'))
        batch_op.drop_index(batch_op.f('ix_behavioral_metric_chunk_question_id'))
        batch_op.drop_index(batch_op.f('ix_behavioral_metric_chunk_answer_id'))

    op.drop_table('behavioral_metric_chunk')
