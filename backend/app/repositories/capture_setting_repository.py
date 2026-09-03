from uuid import UUID
from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.capture_source_setting import CaptureSourceSetting, CaptureSourceType


class CaptureSettingRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_setting(
        self,
        merchant_id: UUID,
        source_type: CaptureSourceType,
        provider_identifier: str
    ) -> Optional[CaptureSourceSetting]:
        return self.db.query(CaptureSourceSetting).filter(
            CaptureSourceSetting.merchant_id == merchant_id,
            CaptureSourceSetting.source_type == source_type,
            CaptureSourceSetting.provider_identifier == provider_identifier
        ).first()

    def list_settings(self, merchant_id: UUID) -> List[CaptureSourceSetting]:
        return self.db.query(CaptureSourceSetting).filter(
            CaptureSourceSetting.merchant_id == merchant_id
        ).all()

    def upsert_setting(
        self,
        merchant_id: UUID,
        source_type: CaptureSourceType,
        provider_identifier: str,
        enabled: bool
    ) -> CaptureSourceSetting:
        setting = self.get_setting(merchant_id, source_type, provider_identifier)
        if setting:
            setting.enabled = enabled
        else:
            setting = CaptureSourceSetting(
                merchant_id=merchant_id,
                source_type=source_type,
                provider_identifier=provider_identifier,
                enabled=enabled
            )
            self.db.add(setting)
        self.db.commit()
        self.db.refresh(setting)
        return setting
