import csv
import json

# Load Dataset 1 and build exact character set & categorical maps
ds1_chars = set()
payment_modes = set()
source_types = set()
statuses = set()

with open('Datasets/DATASET 1/synthetic_transaction_extraction_dataset.csv', 'r', encoding='utf-8', errors='ignore') as f:
    for row in csv.DictReader(f):
        for c in row.get('raw_text', ''):
            ds1_chars.add(c)
        if row.get('payment_mode'): payment_modes.add(row['payment_mode'])
        if row.get('source_type'): source_types.add(row['source_type'])
        if row.get('transaction_status'): statuses.add(row['transaction_status'])

# Standard LabelEncoder sorts classes alphabetically
char_to_id = {'<PAD>': 0, '<UNK>': 1}
for c in sorted(list(ds1_chars)):
    char_to_id[c] = len(char_to_id)

ds1_meta = {
    'vocab': char_to_id,
    'max_len': 128,
    'lowercase': False,
    'payment_mode_map': {i: val for i, val in enumerate(sorted(list(payment_modes)))},
    'source_type_map': {i: val for i, val in enumerate(sorted(list(source_types)))},
    'status_map': {i: val for i, val in enumerate(sorted(list(statuses)))},
}

with open('frontend/assets/models/extraction_metadata.json', 'w', encoding='utf-8') as f:
    json.dump(ds1_meta, f, indent=2)

# Load Dataset 2 and build exact character set & category maps
ds2_chars = set()
categories = set()

with open('Datasets/DATASET 2/meravyapar_transaction_categorization_dataset.csv', 'r', encoding='utf-8', errors='ignore') as f:
    for row in csv.DictReader(f):
        text = f"{row.get('counterparty_name','') or ''} {row.get('transaction_description','') or ''} {row.get('merchant_business_type','') or ''}"
        for c in text:
            ds2_chars.add(c)
        if row.get('category'): categories.add(row['category'])

char_to_id2 = {'<PAD>': 0, '<UNK>': 1}
for c in sorted(list(ds2_chars)):
    char_to_id2[c] = len(char_to_id2)

ds2_meta = {
    'vocab': char_to_id2,
    'max_len': 128,
    'lowercase': False,
    'category_map': {i: val for i, val in enumerate(sorted(list(categories)))},
}

with open('frontend/assets/models/categorization_metadata.json', 'w', encoding='utf-8') as f:
    json.dump(ds2_meta, f, indent=2)

print('Updated metadata JSON files with exact fitted LabelEncoder orderings.')
