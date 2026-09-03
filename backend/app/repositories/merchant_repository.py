from uuid import UUID
from typing import Optional
from sqlalchemy.orm import Session
from app.models.merchant import Merchant
from app.schemas.merchant import MerchantCreate


class MerchantRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_id(self, merchant_id: UUID) -> Optional[Merchant]:
        return self.db.query(Merchant).filter(Merchant.id == merchant_id).first()

    def get_by_auth_user_id(self, auth_user_id: UUID) -> Optional[Merchant]:
        return self.db.query(Merchant).filter(Merchant.auth_user_id == auth_user_id).first()

    def create_merchant(self, auth_user_id: UUID, display_name: Optional[str] = None) -> Merchant:
        merchant = Merchant(
            auth_user_id=auth_user_id,
            display_name=display_name,
            status="ONBOARDING"
        )
        self.db.add(merchant)
        self.db.commit()
        self.db.refresh(merchant)
        return merchant

    def update_status(self, merchant: Merchant, status: str) -> Merchant:
        merchant.status = status
        self.db.commit()
        self.db.refresh(merchant)
        return merchant
