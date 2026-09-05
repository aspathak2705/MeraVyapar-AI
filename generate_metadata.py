import csv
import json

ds1_chars = set()
with open('Datasets/DATASET 1/synthetic_transaction_extraction_dataset.csv', 'r', encoding='utf-8', errors='ignore') as f:
    for row in csv.DictReader(f):
        for c in row.get('raw_text', ''):
            ds1_chars.add(c)

char_to_id = {'<PAD>': 0, '<UNK>': 1}
for c in sorted(list(ds1_chars)):
    char_to_id[c] = len(char_to_id)

ds1_meta = {
    'vocab': char_to_id,
    'payment_mode_map': {0: 'UPI', 1: 'CASH', 2: 'BANK_TRANSFER', 3: 'CARD', 4: 'NEFT', 5: 'IMPS', 6: 'RTGS'},
    'source_type_map': {0: 'NOTIFICATION', 1: 'SMS', 2: 'MANUAL_TEXT'},
    'status_map': {0: 'SUCCESS', 1: 'PENDING', 2: 'FAILED'}
}

with open('extraction_metadata.json', 'w', encoding='utf-8') as f:
    json.dump(ds1_meta, f, indent=2)

ds2_chars = set()
with open('Datasets/DATASET 2/meravyapar_transaction_categorization_dataset.csv', 'r', encoding='utf-8', errors='ignore') as f:
    for row in csv.DictReader(f):
        text = f"{row.get('counterparty_name','') or ''} {row.get('transaction_description','') or ''} {row.get('merchant_business_type','') or ''}"
        for c in text:
            ds2_chars.add(c)

char_to_id2 = {'<PAD>': 0, '<UNK>': 1}
for c in sorted(list(ds2_chars)):
    char_to_id2[c] = len(char_to_id2)

ds2_meta = {
    'vocab': char_to_id2,
    'category_map': {
        0: 'BUSINESS_EXPENSE',
        1: 'FINANCIAL_OBLIGATION',
        2: 'OTHER_INCOME',
        3: 'REVENUE',
        4: 'TRANSFER',
        5: 'UNCATEGORIZED'
    }
}

with open('categorization_metadata.json', 'w', encoding='utf-8') as f:
    json.dump(ds2_meta, f, indent=2)

print('Generated metadata files successfully.')
