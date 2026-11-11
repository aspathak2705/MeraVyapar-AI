"""Simulated Payment Gateway Adapter for Challenge Demonstration.

Strictly isolated in development/demo configuration.
No real money or live financial credentials.
Generates cryptographically signed test webhook events.
Includes replay protection, currency/tenant validation, and production environment guard.
"""
import hmac
import hashlib
import time
import uuid
from typing import Dict, Any, Optional, Set
from pydantic import BaseModel, Field


class ProductionSimulatorDisabledError(RuntimeError):
    """Raised when simulator is invoked in a production environment."""
    pass


class SimulatedPaymentOrder(BaseModel):
    order_id: str
    merchant_id: str
    amount_minor_units: int
    currency: str = "INR"
    status: str = "CREATED"  # CREATED, PAID, FAILED, EXPIRED
    receivable_id: Optional[str] = None
    promise_id: Optional[str] = None
    created_at_epoch: int = Field(default_factory=lambda: int(time.time()))
    expires_at_epoch: int = Field(default_factory=lambda: int(time.time()) + 1800)  # 30 min expiry
    is_simulated: bool = True


class SimulatedPaymentGatewayAdapter:
    def __init__(
        self,
        test_secret: str = "demo-simulated-secret-key-do-not-use-in-prod",
        environment: str = "development"
    ):
        if environment.lower() == "production":
            raise ProductionSimulatorDisabledError("Simulated payment gateway is strictly disabled in production.")

        self.environment = environment
        self.test_secret = test_secret
        self._orders: Dict[str, SimulatedPaymentOrder] = {}
        self._processed_events: Set[str] = set()  # Event replay / duplicate prevention

    def create_simulated_order(
        self,
        merchant_id: str,
        amount_minor_units: int,
        currency: str = "INR",
        receivable_id: Optional[str] = None,
        promise_id: Optional[str] = None,
    ) -> SimulatedPaymentOrder:
        if self.environment.lower() == "production":
            raise ProductionSimulatorDisabledError("Cannot create simulated orders in production.")

        if amount_minor_units <= 0:
            raise ValueError("Amount must be greater than zero integer paise.")
        if currency.upper() != "INR":
            raise ValueError(f"Unsupported currency: {currency}. Only INR supported.")

        order_id = f"sim_ord_{uuid.uuid4().hex[:12]}"
        order = SimulatedPaymentOrder(
            order_id=order_id,
            merchant_id=merchant_id,
            amount_minor_units=amount_minor_units,
            currency=currency.upper(),
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
            "event_id": f"evt_{uuid.uuid4().hex[:12]}",
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
        raw_msg = f"{order.order_id}|{payment_id}|{order.amount_minor_units}|{order.currency}".encode("utf-8")
        signature = hmac.new(self.test_secret.encode("utf-8"), raw_msg, hashlib.sha256).hexdigest()

        if tamper_signature:
            signature = "invalid_tampered_signature"

        return {
            "payload": payload,
            "signature": signature,
        }

    def verify_and_reconcile_event(
        self,
        event_data: Dict[str, Any],
        signature: str,
        expected_merchant_id: str
    ) -> Dict[str, Any]:
        """Comprehensive verification: signature, replay, expiry, tenant isolation, currency."""
        if self.environment.lower() == "production":
            raise ProductionSimulatorDisabledError("Webhook processing blocked in production.")

        # 1. Check simulated provenance
        if not event_data.get("is_simulated", False):
            return {"status": "REJECTED", "reason": "Missing simulated provenance marker"}

        event_id = event_data.get("event_id")
        if not event_id:
            return {"status": "REJECTED", "reason": "Missing event_id"}

        # 2. Replay / Duplicate check
        if event_id in self._processed_events:
            return {"status": "DUPLICATE", "reason": "Event already processed idempotently"}

        order_id = event_data.get("order_id", "")
        payment_id = event_data.get("payment_id", "")
        amount = event_data.get("amount_minor_units", 0)
        currency = event_data.get("currency", "")
        event_merchant = event_data.get("merchant_id", "")

        # 3. Tenant Isolation Check
        if event_merchant != expected_merchant_id:
            return {"status": "REJECTED", "reason": "Cross-merchant event rejected"}

        # 4. Currency Check
        if currency.upper() != "INR":
            return {"status": "REJECTED", "reason": "Invalid currency"}

        # 5. Order Lookup & Expiry Check
        order = self._orders.get(order_id)
        if not order:
            return {"status": "REJECTED", "reason": "Order not found"}

        if int(time.time()) > order.expires_at_epoch:
            return {"status": "REJECTED", "reason": "Order expired"}

        if order.status == "PAID":
            return {"status": "REJECTED", "reason": "Order already settled"}

        # 6. Timing-Safe HMAC Verification
        raw_msg = f"{order_id}|{payment_id}|{amount}|{currency}".encode("utf-8")
        expected_sig = hmac.new(self.test_secret.encode("utf-8"), raw_msg, hashlib.sha256).hexdigest()

        if not hmac.compare_digest(expected_sig, signature):
            return {"status": "REJECTED", "reason": "Invalid or tampered HMAC signature"}

        # 7. Amount Match Check
        if amount != order.amount_minor_units:
            return {"status": "REJECTED", "reason": "Amount mismatch"}

        # Mark settled & store processed event ID
        order.status = "PAID"
        self._processed_events.add(event_id)

        return {
            "status": "RECONCILED",
            "order_id": order_id,
            "payment_id": payment_id,
            "reconciled_amount_paise": amount,
            "promise_id": order.promise_id,
            "receivable_id": order.receivable_id,
            "is_simulated": True
        }
