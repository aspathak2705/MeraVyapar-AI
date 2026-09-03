"""003_reconciliation_and_canonical_transactions

Revision ID: 003_reconciliation_and_canonical_transactions
Revises: 002_evidence_and_transaction_candidates
Create Date: 2026-09-03

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '003_reconciliation_and_canonical_transactions'
down_revision = '002_evidence_and_transaction_candidates'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Create idempotency_records table
    op.create_table(
        'idempotency_records',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('idempotency_key', sa.String(length=255), nullable=False),
        sa.Column('request_hash', sa.String(length=255), nullable=True),
        sa.Column('resource_type', sa.String(length=100), nullable=False),
        sa.Column('resource_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint('merchant_id', 'idempotency_key', name='uq_merchant_idempotency_key')
    )
    op.create_index('ix_idempotency_records_merchant_key', 'idempotency_records', ['merchant_id', 'idempotency_key'], unique=False)

    # 2. Create canonical_transactions table
    op.create_table(
        'canonical_transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('amount', sa.Numeric(precision=18, scale=2), nullable=True),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='INR'),
        sa.Column('transaction_type', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('payment_mode', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('counterparty_name', sa.String(length=255), nullable=True),
        sa.Column('transaction_reference', sa.String(length=255), nullable=True),
        sa.Column('occurred_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('reconciliation_status', sa.String(length=50), nullable=False, server_default='UNRESOLVED'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(op.f('ix_canonical_transactions_merchant_id'), 'canonical_transactions', ['merchant_id'], unique=False)
    op.create_index('ix_canonical_transactions_merchant_occurred', 'canonical_transactions', ['merchant_id', 'occurred_at'], unique=False)
    op.create_index('ix_canonical_transactions_status', 'canonical_transactions', ['reconciliation_status'], unique=False)

    # 3. Create transaction_candidate_links table
    op.create_table(
        'transaction_candidate_links',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('canonical_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('canonical_transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('transaction_candidate_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transaction_candidates.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('relationship_type', sa.String(length=50), nullable=False, server_default='PRIMARY'),
        sa.Column('linked_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('linked_by', sa.String(length=50), nullable=False, server_default='SYSTEM_RECONCILIATION'),
        sa.UniqueConstraint('transaction_candidate_id', name='uq_candidate_single_canonical_link')
    )
    op.create_index(op.f('ix_transaction_candidate_links_merchant_id'), 'transaction_candidate_links', ['merchant_id'], unique=False)
    op.create_index('ix_candidate_links_canonical_cand', 'transaction_candidate_links', ['canonical_transaction_id', 'transaction_candidate_id'], unique=False)

    # 4. Create reconciliation_attempts table
    op.create_table(
        'reconciliation_attempts',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('transaction_candidate_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transaction_candidates.id', ondelete='CASCADE'), nullable=False),
        sa.Column('compared_candidate_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transaction_candidates.id', ondelete='SET NULL'), nullable=True),
        sa.Column('canonical_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('canonical_transactions.id', ondelete='SET NULL'), nullable=True),
        sa.Column('decision', sa.String(length=50), nullable=False),
        sa.Column('reason_codes', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='[]'),
        sa.Column('comparison_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(op.f('ix_reconciliation_attempts_merchant_id'), 'reconciliation_attempts', ['merchant_id'], unique=False)
    op.create_index('ix_reconciliation_attempts_merchant_created', 'reconciliation_attempts', ['merchant_id', 'created_at'], unique=False)


def downgrade() -> None:
    op.drop_table('reconciliation_attempts')
    op.drop_table('transaction_candidate_links')
    op.drop_table('canonical_transactions')
    op.drop_table('idempotency_records')
