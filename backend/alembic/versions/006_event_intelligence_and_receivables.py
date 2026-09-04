"""006_event_intelligence_and_receivables

Revision ID: 006_event_intelligence_and_receivables
Revises: 005_financial_memory_graph
Create Date: 2026-09-04

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '006_event_intelligence_and_receivables'
down_revision = '005_financial_memory_graph'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'financial_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('severity', sa.String(length=50), nullable=False, server_default='INFO'),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='ACTIVE'),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('summary', sa.String(length=255), nullable=False),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('detected_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('source_entity_type', sa.String(length=50), nullable=False),
        sa.Column('source_entity_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('deduplication_key', sa.String(length=255), nullable=True),
        sa.Column('metadata', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('merchant_id', 'deduplication_key', name='uq_merchant_event_dedup')
    )
    op.create_index(op.f('ix_financial_events_merchant_id'), 'financial_events', ['merchant_id'], unique=False)
    op.create_index('ix_financial_events_merchant_status', 'financial_events', ['merchant_id', 'status'], unique=False)
    op.create_index('ix_financial_events_type_severity', 'financial_events', ['event_type', 'severity'], unique=False)


def downgrade() -> None:
    op.drop_table('financial_events')
