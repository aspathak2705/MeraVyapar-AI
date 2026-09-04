"""008_market_intelligence_foundation

Revision ID: 008_market_intelligence_foundation
Revises: 007_grounded_financial_intelligence
Create Date: 2026-09-04

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '008_market_intelligence_foundation'
down_revision = '007_grounded_financial_intelligence'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. market_sources
    op.create_table(
        'market_sources',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('provider_name', sa.String(length=50), nullable=False),
        sa.Column('source_name', sa.String(length=100), nullable=False),
        sa.Column('source_url', sa.String(length=500), nullable=False),
        sa.Column('external_identifier', sa.String(length=255), nullable=True),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('published_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('retrieved_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('content_hash', sa.String(length=64), nullable=False),
        sa.Column('metadata', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('provider_name', 'content_hash', name='uq_market_source_provider_hash')
    )
    op.create_index('ix_market_sources_provider_published', 'market_sources', ['provider_name', 'published_at'], unique=False)

    # 2. market_events
    op.create_table(
        'market_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('event_type', sa.String(length=50), nullable=False, server_default='OTHER'),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('summary', sa.String(length=500), nullable=False),
        sa.Column('geography', sa.String(length=100), nullable=True, server_default='IN'),
        sa.Column('sector', sa.String(length=100), nullable=True),
        sa.Column('affected_domains', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('event_status', sa.String(length=50), nullable=False, server_default='ACTIVE'),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('detected_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('source_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('market_sources.id', ondelete='CASCADE'), nullable=False),
        sa.Column('reason_codes', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('metadata', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()'))
    )
    op.create_index(op.f('ix_market_events_source_id'), 'market_events', ['source_id'], unique=False)
    op.create_index('ix_market_events_type_occurred', 'market_events', ['event_type', 'occurred_at'], unique=False)

    # 3. merchant_market_relevance
    op.create_table(
        'merchant_market_relevance',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('market_event_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('market_events.id', ondelete='CASCADE'), nullable=False),
        sa.Column('relevance_status', sa.String(length=50), nullable=False, server_default='NOT_RELEVANT'),
        sa.Column('reason_codes', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('context_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('detected_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='ACTIVE'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('merchant_id', 'market_event_id', name='uq_merchant_market_relevance')
    )
    op.create_index(op.f('ix_merchant_market_relevance_merchant_id'), 'merchant_market_relevance', ['merchant_id'], unique=False)
    op.create_index(op.f('ix_merchant_market_relevance_market_event_id'), 'merchant_market_relevance', ['market_event_id'], unique=False)
    op.create_index('ix_merchant_market_relevance_merchant_status', 'merchant_market_relevance', ['merchant_id', 'status'], unique=False)


def downgrade() -> None:
    op.drop_table('merchant_market_relevance')
    op.drop_table('market_events')
    op.drop_table('market_sources')
