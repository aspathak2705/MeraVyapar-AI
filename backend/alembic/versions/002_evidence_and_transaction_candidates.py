"""002_evidence_and_transaction_candidates

Revision ID: 002_evidence_and_transaction_candidates
Revises: 001_initial_schema
Create Date: 2026-09-03

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '002_evidence_and_transaction_candidates'
down_revision = '001_initial_schema'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Create financial_evidence table
    op.create_table(
        'financial_evidence',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('evidence_type', sa.String(length=50), nullable=False),
        sa.Column('evidence_source', sa.String(length=50), nullable=False),
        sa.Column('evidence_strength', sa.String(length=50), nullable=False),
        sa.Column('raw_text', sa.Text(), nullable=True),
        sa.Column('metadata', postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default='{}'),
        sa.Column('storage_object_key', sa.String(length=512), nullable=True),
        sa.Column('content_type', sa.String(length=100), nullable=True),
        sa.Column('original_filename', sa.String(length=255), nullable=True),
        sa.Column('idempotency_key', sa.String(length=255), nullable=True),
        sa.Column('processing_status', sa.String(length=50), nullable=False, server_default='RECEIVED'),
        sa.Column('received_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('processed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(op.f('ix_financial_evidence_merchant_id'), 'financial_evidence', ['merchant_id'], unique=False)
    op.create_index('ix_financial_evidence_merchant_created', 'financial_evidence', ['merchant_id', 'created_at'], unique=False)
    op.create_index('ix_financial_evidence_status', 'financial_evidence', ['processing_status'], unique=False)
    op.create_index('ix_financial_evidence_type', 'financial_evidence', ['evidence_type'], unique=False)
    op.create_index(op.f('ix_financial_evidence_idempotency_key'), 'financial_evidence', ['idempotency_key'], unique=False)

    # 2. Create transaction_candidates table
    op.create_table(
        'transaction_candidates',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('primary_evidence_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('financial_evidence.id', ondelete='CASCADE'), nullable=False),
        sa.Column('transaction_type', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('amount', sa.Numeric(precision=18, scale=2), nullable=True),
        sa.Column('currency', sa.String(length=3), nullable=False, server_default='INR'),
        sa.Column('transaction_timestamp', sa.DateTime(timezone=True), nullable=True),
        sa.Column('counterparty_name', sa.String(length=255), nullable=True),
        sa.Column('payment_mode', sa.String(length=50), nullable=False, server_default='UNKNOWN'),
        sa.Column('reference_number', sa.String(length=255), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('normalization_status', sa.String(length=50), nullable=False, server_default='PENDING'),
        sa.Column('review_status', sa.String(length=50), nullable=False, server_default='NOT_REQUIRED'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
    )
    op.create_index(op.f('ix_transaction_candidates_merchant_id'), 'transaction_candidates', ['merchant_id'], unique=False)
    op.create_index(op.f('ix_transaction_candidates_primary_evidence_id'), 'transaction_candidates', ['primary_evidence_id'], unique=False)
    op.create_index('ix_transaction_candidates_merchant_timestamp', 'transaction_candidates', ['merchant_id', 'transaction_timestamp'], unique=False)
    op.create_index('ix_transaction_candidates_type', 'transaction_candidates', ['transaction_type'], unique=False)


def downgrade() -> None:
    op.drop_table('transaction_candidates')
    op.drop_table('financial_evidence')
