"""005_financial_memory_graph

Revision ID: 005_financial_memory_graph
Revises: 004_transaction_capture_expansion
Create Date: 2026-09-03

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '005_financial_memory_graph'
down_revision = '004_transaction_capture_expansion'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. financial_counterparties
    op.create_table(
        'financial_counterparties',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('display_name', sa.String(length=255), nullable=False),
        sa.Column('normalized_name', sa.String(length=255), nullable=False),
        sa.Column('relationship_type', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='ACTIVE'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(op.f('ix_financial_counterparties_merchant_id'), 'financial_counterparties', ['merchant_id'], unique=False)
    op.create_index('ix_counterparties_merchant_normalized', 'financial_counterparties', ['merchant_id', 'normalized_name'], unique=False)

    # 2. counterparty_aliases
    op.create_table(
        'counterparty_aliases',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('counterparty_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_counterparties.id', ondelete='CASCADE'), nullable=False),
        sa.Column('alias_value', sa.String(length=255), nullable=False),
        sa.Column('normalized_alias', sa.String(length=255), nullable=False),
        sa.Column('source', sa.String(length=50), nullable=False, server_default='EXACT_MATCH'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('merchant_id', 'normalized_alias', name='uq_merchant_normalized_alias')
    )
    op.create_index(op.f('ix_counterparty_aliases_merchant_id'), 'counterparty_aliases', ['merchant_id'], unique=False)
    op.create_index('ix_aliases_merchant_normalized', 'counterparty_aliases', ['merchant_id', 'normalized_alias'], unique=False)

    # 3. merchant_counterparty_relationships
    op.create_table(
        'merchant_counterparty_relationships',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('counterparty_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_counterparties.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('relationship_type', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('relationship_status', sa.String(length=50), nullable=False, server_default='OBSERVED'),
        sa.Column('first_seen_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('last_seen_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('transaction_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('merchant_id', 'counterparty_id', name='uq_merchant_counterparty_rel')
    )

    # 4. transaction_counterparty_links
    op.create_table(
        'transaction_counterparty_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('canonical_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('canonical_transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('counterparty_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_counterparties.id', ondelete='CASCADE'), nullable=False),
        sa.Column('link_type', sa.String(length=50), nullable=False, server_default='PRIMARY_COUNTERPARTY'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('canonical_transaction_id', 'link_type', name='uq_canonical_primary_counterparty')
    )

    # 5. payment_promises
    op.create_table(
        'payment_promises',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('counterparty_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_counterparties.id', ondelete='SET NULL'), nullable=True),
        sa.Column('description', sa.String(length=255), nullable=False),
        sa.Column('promised_amount', sa.Numeric(precision=18, scale=2), nullable=False),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='INR'),
        sa.Column('promise_direction', sa.String(length=50), nullable=False, server_default='EXPECTED_INCOMING'),
        sa.Column('due_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='OPEN'),
        sa.Column('source', sa.String(length=50), nullable=False, server_default='MERCHANT_DECLARED'),
        sa.Column('source_reference', sa.String(length=255), nullable=True),
        sa.Column('fulfilled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index('ix_payment_promises_merchant_due', 'payment_promises', ['merchant_id', 'due_at'], unique=False)
    op.create_index('ix_payment_promises_status', 'payment_promises', ['status'], unique=False)

    # 6. financial_relationship_events
    op.create_table(
        'financial_relationship_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('counterparty_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_counterparties.id', ondelete='CASCADE'), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('canonical_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('canonical_transactions.id', ondelete='SET NULL'), nullable=True),
        sa.Column('payment_promise_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('payment_promises.id', ondelete='SET NULL'), nullable=True),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('metadata', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index('ix_relationship_events_merchant_counterparty', 'financial_relationship_events', ['merchant_id', 'counterparty_id', 'occurred_at'], unique=False)

    # 7. payment_promise_events
    op.create_table(
        'payment_promise_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('payment_promise_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('payment_promises.id', ondelete='CASCADE'), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('previous_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('new_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )


def downgrade() -> None:
    op.drop_table('payment_promise_events')
    op.drop_table('financial_relationship_events')
    op.drop_table('payment_promises')
    op.drop_table('transaction_counterparty_links')
    op.drop_table('merchant_counterparty_relationships')
    op.drop_table('counterparty_aliases')
    op.drop_table('financial_counterparties')
