import os
import json
import csv
from typing import Optional, Dict, Any, List
from app.core.logging import logger

DATASETS_BASE_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))),
    "Datasets"
)


class DatasetRegistry:
    _instance: Optional['DatasetRegistry'] = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatasetRegistry, cls).__new__(cls)
            cls._instance._datasets_cache = {}
            cls._instance._load_datasets()
        return cls._instance

    def _load_datasets(self):
        # Load Dataset 0: Merchant Financial World
        ds0_path = os.path.join(DATASETS_BASE_DIR, "DATASET 0", "merchant_financial_world.json")
        if os.path.exists(ds0_path):
            try:
                with open(ds0_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        self._datasets_cache["dataset_0"] = data
                        logger.info(f"DatasetRegistry: Loaded Dataset 0 ({len(data)} records)")
                    else:
                        logger.error("DatasetRegistry: Dataset 0 invalid format (expected list)")
            except Exception as e:
                logger.error(f"DatasetRegistry: Error loading Dataset 0: {str(e)}")

        # Load Dataset 3 Metadata & Summary
        ds3_meta_path = os.path.join(DATASETS_BASE_DIR, "DATASET 3", "cashflow_dataset_metadata.json")
        if os.path.exists(ds3_meta_path):
            try:
                with open(ds3_meta_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        self._datasets_cache["dataset_3_metadata"] = data
                        logger.info("DatasetRegistry: Loaded Dataset 3 metadata")
                    else:
                        logger.error("DatasetRegistry: Dataset 3 metadata invalid format")
            except Exception as e:
                logger.error(f"DatasetRegistry: Error loading Dataset 3 metadata: {str(e)}")

        # Load Dataset 4 Metadata
        ds4_meta_path = os.path.join(DATASETS_BASE_DIR, "DATASET 4", "synthetic_receivable_behavior_dataset_metadata.json")
        if os.path.exists(ds4_meta_path):
            try:
                with open(ds4_meta_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        self._datasets_cache["dataset_4_metadata"] = data
                        logger.info("DatasetRegistry: Loaded Dataset 4 metadata")
                    else:
                        logger.error("DatasetRegistry: Dataset 4 metadata invalid format")
            except Exception as e:
                logger.error(f"DatasetRegistry: Error loading Dataset 4 metadata: {str(e)}")

    def get_dataset(self, name: str) -> Optional[Any]:
        return self._datasets_cache.get(name)

    def is_available(self, name: str) -> bool:
        return name in self._datasets_cache


dataset_registry = DatasetRegistry()
