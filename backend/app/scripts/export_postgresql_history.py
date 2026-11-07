"""
MeraVyapar AI - Read-Only Historical PostgreSQL Export Generator.
Exports financial data for an explicitly specified merchant in read-only transaction mode.
Zero mutation. Zero updates. Zero deletes.
"""

import os
import sys
import json
import uuid
import hashlib
from datetime import datetime, timezone
from decimal import Decimal
from typing import Dict, Any, List, Optional
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Custom JSON encoder for UUID, Decimal, and DateTime
class ExactFinancialJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, uuid.UUID):
            return str(obj)
        if isinstance(obj, Decimal):
            # Preserve exact decimal string without float drift
            return str(obj)
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


def generate_read_only_export(
    database_url: str,
    merchant_id: str,
    output_dir: str = "export_output"
) -> Dict[str, Any]:
    """
    Executes a read-only transaction to export a merchant's complete financial history.
    """
    os.makedirs(output_dir, exist_ok=True)
    engine = create_engine(database_url, isolation_level="REPEATABLE READ")

    with engine.connect() as connection:
        # Enforce read-only transaction mode at database session level
        connection.execute(text("SET TRANSACTION READ ONLY;"))

        # 1. Merchant Profile
        merchant_res = connection.execute(
            text("SELECT id, auth_user_id, display_name, status, created_at, updated_at FROM merchants WHERE id = :mid"),
            {"mid": merchant_id}
        ).mappings().first()

        if not merchant_res:
            raise ValueError(f"Merchant with ID {merchant_id} not found in PostgreSQL database.")

        merchant_data = dict(merchant_res)

        # 2. Business Profile
        bp_res = connection.execute(
            text("SELECT id, business_name, business_category, primary_currency FROM business_profiles WHERE merchant_id = :mid"),
            {"mid": merchant_id}
        ).mappings().first()
        bp_data = dict(bp_res) if bp_res else None

        # 3. Financial Counterparties
        cp_res = connection.execute(
            text("SELECT id, merchant_id, name, phone_number, category, created_at, updated_at FROM financial_counterparties WHERE merchant_id = :mid"),
            {"mid": merchant_id}
        ).mappings().all()
        cp_data = [dict(r) for r in cp_res]

        # 4. Canonical Transactions
        tx_res = connection.execute(
            text("""
                SELECT id, merchant_id, amount, currency, transaction_type, payment_mode,
                       counterparty_name, transaction_reference, occurred_at, source_type,
                       source_provider, is_simulated, reconciliation_status, created_at
                FROM canonical_transactions
                WHERE merchant_id = :mid
                ORDER BY occurred_at ASC
            """),
            {"mid": merchant_id}
        ).mappings().all()
        tx_data = [dict(r) for r in tx_res]

        # 5. Payment Promises
        pr_res = connection.execute(
            text("""
                SELECT id, merchant_id, counterparty_id, counterparty_name, amount,
                       currency, direction, status, source, due_date, created_at, fulfilled_at, notes
                FROM payment_promises
                WHERE merchant_id = :mid
                ORDER BY due_date ASC
            """),
            {"mid": merchant_id}
        ).mappings().all()
        pr_data = [dict(r) for r in pr_res]

        # 6. Financial Events
        ev_res = connection.execute(
            text("SELECT id, merchant_id, event_type, title, description, amount, event_date, severity, status, created_at FROM financial_events WHERE merchant_id = :mid"),
            {"mid": merchant_id}
        ).mappings().all()
        ev_data = [dict(r) for r in ev_res]

        # 7. Evidence Metadata
        med_res = connection.execute(
            text("SELECT id, merchant_id, filename, mime_type, file_size_bytes, sha256_hash, storage_path, captured_at, source_type FROM financial_evidence WHERE merchant_id = :mid"),
            {"mid": merchant_id}
        ).mappings().all()
        med_data = [dict(r) for r in med_res]

        # 8. Communication Drafts
        comm_res = connection.execute(
            text("SELECT id, merchant_id, promise_id, channel, recipient_phone, recipient_name, draft_content, status, created_at, dispatched_at FROM communication_actions WHERE merchant_id = :mid"),
            {"mid": merchant_id}
        ).mappings().all()
        comm_data = [dict(r) for r in comm_res]

    export_payload = {
        "contract_version": "1.0",
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "source_system": "PostgreSQL_Backend",
        "merchant": merchant_data,
        "business_profile": bp_data,
        "counterparties": cp_data,
        "transactions": tx_data,
        "promises": pr_data,
        "financial_events": ev_data,
        "evidence_metadata": med_data,
        "communication_drafts": comm_data,
        "record_counts": {
            "merchants": 1,
            "business_profiles": 1 if bp_data else 0,
            "counterparties": len(cp_data),
            "transactions": len(tx_data),
            "promises": len(pr_data),
            "financial_events": len(ev_data),
            "evidence_metadata": len(med_data),
            "communication_drafts": len(comm_data),
        }
    }

    # Deterministic JSON export
    raw_json = json.dumps(export_payload, cls=ExactFinancialJSONEncoder, indent=2, sort_keys=True)
    chk = hashlib.sha256(raw_json.encode('utf-8')).hexdigest()
    export_payload["checksum_sha256"] = chk

    final_json = json.dumps(export_payload, cls=ExactFinancialJSONEncoder, indent=2, sort_keys=True)
    out_filename = f"meravyapar_export_{merchant_id[:8]}_{int(datetime.now().timestamp())}.json"
    out_path = os.path.join(output_dir, out_filename)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(final_json)

    return {
        "success": True,
        "export_path": out_path,
        "checksum": chk,
        "record_counts": export_payload["record_counts"]
    }


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python export_postgresql_history.py <DATABASE_URL> <MERCHANT_ID>")
        sys.exit(1)
    res = generate_read_only_export(sys.argv[1], sys.argv[2])
    print("Export completed successfully:", res)
