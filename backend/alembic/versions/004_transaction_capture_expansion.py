"""004_transaction_capture_expansion

Revision ID: 004_transaction_capture_expansion
Revises: 003_reconciliation_and_canonical_transactions
Create Date: 2026-09-03

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = '004_transaction_capture_expansion'
down_revision = '003_reconciliation_and_canonical_transactions'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'capture_source_settings',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id', ondelete='CASCADE'), nullable=False),
        sa.Column('source_type', sa.String(length=50), nullable=False),
        sa.Column('provider_identifier', sa.String(length=100), nullable=False),
        sa.Column('enabled', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.UniqueConstraint('merchant_id', 'source_type', 'provider_identifier', name='uq_merchant_capture_provider')
    )
    op.create_index(op.f('ix_capture_source_settings_merchant_id'), 'capture_source_settings', ['merchant_id'], unique=False)
    op.create_index('ix_capture_source_settings_merchant_provider', 'capture_source_settings', ['merchant_id', 'source_type', 'provider_identifier'], unique=False)


def downgrade() -> None:
    op.drop_table('capture_source_settings')
