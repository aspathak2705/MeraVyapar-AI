"""Simulated Payment Gateway Adapter for Challenge Demonstration.

Strictly isolated in development/demo configuration.
No real money or live financial credentials.
Generates cryptographically signed test webhook events.
"""
import hmac
import hashlib
import time
import uuid
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field


class SimulatedPaymentOrder(BaseModel):
    order_id: str
    merchant_id: str
    amount_minor_units: int
    currency: str = "INR"
    status: str = "CREATED"  # CREATED, PAID, FAILED
    receivable_id: Optional[str] = None
    promise_id: Optional[str] = None
    created_at_epoch: int = Field(default_factory=lambda: int(time.time()))
    is_simulated: bool = True


class SimulatedPaymentGatewayAdapter:
    def __init__(self, test_secret: str = "demo-simulated-secret-key-do-not-use-in-prod"):
        self.test_secret = test_secret
        self._orders: Dict[str, SimulatedPaymentOrder] = {}

    def create_simulated_order(
        self,
        merchant_id: str,
        amount_minor_units: int,
        receivable_id: Optional[str] = None,
        promise_id: Optional[str] = None,
    ) -> SimulatedPaymentOrder:
        order_id = f"sim_ord_{uuid.uuid4().hex[:12]}"
        order = SimulatedPaymentOrder(
            order_id=order_id,
            merchant_id=merchant_id,
            amount_minor_units=amount_minor_units,
            receivable_id=receivable_id,
            promise_id=promise_id,
        )
        self._orders[order_id] = order
        return order

    def generate_signed_event(
        self,
        order_id: str,
        event_type: str = "payment.simulated.success",
        tamper_signature: bool = False,
    ) -> Dict[str, Any]:
        order = self._orders.get(order_id)
        if not order:
            raise ValueError(f"Simulated order {order_id} not found")

        payment_id = f"sim_pay_{uuid.uuid4().hex[:12]}"
        payload = {
            "event": event_type,
            "order_id": order.order_id,
            "payment_id": payment_id,
            "merchant_id": order.merchant_id,
            "amount_minor_units": order.amount_minor_units,
            "currency": order.currency,
            "receivable_id": order.receivable_id,
            "promise_id": order.promise_id,
            "timestamp": int(time.time()),
            "is_simulated": True,
        }

        # Calculate HMAC-SHA256 signature
        raw_msg = f"{order.order_id}|{payment_id}|{order.amount_minor_units}".encode("utf-8")
        signature = hmac.new(self.test_secret.encode("utf-8"), raw_msg, hashlib.sha256).hexdigest()

        if tamper_signature:
            signature = "invalid_tampered_signature"

        return {
            "payload": payload,
            "signature": signature,
        }

    def verify_event_signature(self, event_data: Dict[str, Any], signature: str) -> bool:
        order_id = event_data.get("order_id", "")
        payment_id = event_data.get("payment_id", "")
        amount = event_data.get("amount_minor_units", 0)

        raw_msg = f"{order_id}|{payment_id}|{amount}".encode("utf-8")
        expected_sig = hmac.new(self.test_secret.encode("utf-8"), raw_msg, hashlib.sha256).hexdigest()

        return hmac.compare_digest(expected_sig, signature)
