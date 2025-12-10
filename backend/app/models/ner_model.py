from functools import lru_cache
from pathlib import Path
from typing import List

import torch
from transformers import AutoTokenizer, AutoModelForTokenClassification


# Paths to your local model + tokenizer
BASE_DIR = Path(__file__).parent
MODEL_DIR = BASE_DIR / "ALL_MBERT_NER_model"
TOKENIZER_DIR = BASE_DIR / "ALL_MBERT_NER_tokenizer"


@lru_cache(maxsize=1)
def get_tokenizer():
    """
    Load the tokenizer once and cache it.
    """
    tokenizer = AutoTokenizer.from_pretrained(str(TOKENIZER_DIR))
    return tokenizer


@lru_cache(maxsize=1)
def get_model():
    """
    Load the NER model once and cache it.
    """
    model = AutoModelForTokenClassification.from_pretrained(str(MODEL_DIR))
    model.eval()
    return model


def _clean_tokens(tokens: List[str]) -> str:
    """
    Convert wordpiece tokens back into a clean string.
    E.g., ['ab', '##dom', '##inal', 'pain'] -> 'abdominal pain'
    """
    text = ""
    for tok in tokens:
        if tok.startswith("##"):
            text += tok[2:]
        elif len(text) == 0:
            text += tok
        else:
            text += " " + tok
    return text


def extract_adr_mentions(text: str, max_length: int = 256) -> List[str]:
    """
    Run the MBERT NER model on the given text and return a list of ADR-like mentions.

    NOTE:
      - config.json defines id2label: { "0": "LABEL_0", "1": "LABEL_1", ... }
      - We don't know the exact label meaning, so for now:
        * LABEL_0  -> treat as "O" (non-entity)
        * others   -> treat as ADR entities
      - If your colleague has a specific mapping (e.g. LABEL_1=ADR, LABEL_2=DRUG),
        you can refine the logic below accordingly.
    """
    if not text:
        return []

    tokenizer = get_tokenizer()
    model = get_model()

    encoded = tokenizer(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=max_length,
        is_split_into_words=False,
    )

    with torch.no_grad():
        outputs = model(**encoded)
        logits = outputs.logits  # (batch_size, seq_len, num_labels)
        pred_ids = torch.argmax(logits, dim=-1)[0].tolist()

    tokens = tokenizer.convert_ids_to_tokens(encoded["input_ids"][0])
    id2label = model.config.id2label  # keys are strings: "0", "1", ...

    entities: List[str] = []
    current_tokens: List[str] = []

    special_tokens = set(tokenizer.all_special_tokens)

    for tok, pid in zip(tokens, pred_ids):
        if tok in special_tokens:
            # boundary: flush any current entity
            if current_tokens:
                entities.append(_clean_tokens(current_tokens))
                current_tokens = []
            continue

        label = id2label.get(str(pid), "LABEL_0")

        if label == "LABEL_0":
            # non-entity
            if current_tokens:
                entities.append(_clean_tokens(current_tokens))
                current_tokens = []
        else:
            # entity token – treat all LABEL_1/2/3/4 as ADR-type for now
            current_tokens.append(tok)

    if current_tokens:
        entities.append(_clean_tokens(current_tokens))

    # Deduplicate
    deduped = []
    for e in entities:
        if e not in deduped:
            deduped.append(e)

    return deduped
