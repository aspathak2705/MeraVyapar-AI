"""007_grounded_financial_intelligence

Revision ID: 007_grounded_financial_intelligence
Revises: 006_event_intelligence_and_receivables
Create Date: 2026-09-04

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '007_grounded_financial_intelligence'
down_revision = '006_event_intelligence_and_receivables'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'generated_insights',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('insight_type', sa.String(length=50), nullable=False),
        sa.Column('focus_entity_type', sa.String(length=50), nullable=True),
        sa.Column('focus_entity_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('context_version', sa.String(length=50), nullable=False, server_default='1.0'),
        sa.Column('content', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('source_references', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('model_identifier', sa.String(length=100), nullable=False, server_default='gemini-1.5-flash'),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='CURRENT'),
        sa.Column('generated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('stale_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()'))
    )
    op.create_index(op.f('ix_generated_insights_merchant_id'), 'generated_insights', ['merchant_id'], unique=False)
    op.create_index('ix_insights_merchant_focus', 'generated_insights', ['merchant_id', 'focus_entity_type', 'focus_entity_id'], unique=False)


def downgrade() -> None:
    op.drop_table('generated_insights')
