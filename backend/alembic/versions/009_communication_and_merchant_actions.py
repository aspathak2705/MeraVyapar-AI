"""009 communication and merchant actions

Revision ID: 009_communication_and_merchant_actions
Revises: 008_market_intelligence
Create Date: 2026-09-04 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '009_communication_and_merchant_actions'
down_revision = '008_market_intelligence'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'communication_actions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id'), nullable=False),
        sa.Column('action_type', sa.String(50), nullable=False),
        sa.Column('channel', sa.String(20), nullable=False),
        sa.Column('status', sa.String(30), nullable=False),
        sa.Column('draft_content', sa.Text(), nullable=False),
        sa.Column('final_content', sa.Text(), nullable=True),
        sa.Column('recipient_info', postgresql.JSONB(as_text=True), nullable=True),
        sa.Column('target_entity_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('target_entity_type', sa.String(50), nullable=True),
        sa.Column('promise_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('payment_promises.id'), nullable=True),
        sa.Column('idempotency_key', sa.String(255), nullable=False, unique=True),
        sa.Column('provider_message_id', sa.String(255), nullable=True),
        sa.Column('error_code', sa.String(50), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('sent_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_communication_actions_merchant_id', 'communication_actions', ['merchant_id'])
    op.create_index('ix_communication_actions_promise_id', 'communication_actions', ['promise_id'])
    op.create_index('ix_communication_actions_idempotency_key', 'communication_actions', ['idempotency_key'])

    op.create_table(
        'communication_action_events',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('action_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('communication_actions.id'), nullable=False),
        sa.Column('merchant_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('merchants.id'), nullable=False),
        sa.Column('previous_status', sa.String(30), nullable=True),
        sa.Column('new_status', sa.String(30), nullable=False),
        sa.Column('actor', sa.String(50), nullable=False),
        sa.Column('reason', sa.Text(), nullable=True),
        sa.Column('event_metadata', postgresql.JSONB(as_text=True), nullable=True),
        sa.Column('timestamp', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index('ix_communication_action_events_action_id', 'communication_action_events', ['action_id'])
    op.create_index('ix_communication_action_events_merchant_id', 'communication_action_events', ['merchant_id'])


def downgrade() -> None:
    op.drop_table('communication_action_events')
    op.drop_table('communication_actions')
