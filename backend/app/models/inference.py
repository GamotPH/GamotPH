import numpy as np
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForTokenClassification, TrainingArguments, Trainer
import torch

def extract_drug(tokens, labels, target_label="DRUG"):
    entities = []
    current_entity = []
    inside_entity = False

    for token, label in zip(tokens, labels):
        if token in ("[CLS]", "[SEP]"):
            continue  # skip special tokens

        if label == f"B-{target_label}":
            # Save previous entity
            if current_entity:
                entities.append((" ".join(current_entity), target_label))
            current_entity = [token if not token.startswith("##") else token[2:]]
            inside_entity = True

        elif label == f"I-{target_label}" and inside_entity:
            if token.startswith("##"):
                current_entity[-1] += token[2:]
            else:
                current_entity.append(token)

        else:
            # End of current entity
            if current_entity:
                entities.append((" ".join(current_entity), target_label))
                current_entity = []
            inside_entity = False

    # Catch last entity
    if current_entity:
        entities.append((" ".join(current_entity), target_label))

    return entities



def extract_adr(tokens, labels, target_label="ADR"):
    entities = []
    current_entity = []
    inside_entity = False

    for token, label in zip(tokens, labels):
        if token in ("[CLS]", "[SEP]"):
            continue  # skip special tokens

        if label == f"B-{target_label}":
            # Save previous entity
            if current_entity:
                entities.append((" ".join(current_entity), target_label))
            current_entity = [token if not token.startswith("##") else token[2:]]
            inside_entity = True

        elif label == f"I-{target_label}" and inside_entity:
            if token.startswith("##"):
                current_entity[-1] += token[2:]
            else:
                current_entity.append(token)

        else:
            # End of current entity
            if current_entity:
                entities.append((" ".join(current_entity), target_label))
                current_entity = []
            inside_entity = False

    # Catch last entity
    if current_entity:
        entities.append((" ".join(current_entity), target_label))

    return entities

label_list = ["O", "B-DRUG", "I-DRUG","B-ADR","I-ADR"]

model = AutoModelForTokenClassification.from_pretrained('ALL_MBERT_NER_model', num_labels=len(label_list))
tokenizer = AutoTokenizer.from_pretrained('ALL_MBERT_NER_tokenizer')

#device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
device = "cpu"
model.to(device)



# Inference with the trained model
test_sentence = "gi hilanat ako iti biogesic"  # Replace with any multilingual test sentence
#test_sentence = input("Enter your sentence: ")
tokens = tokenizer(test_sentence, return_tensors="pt", truncation=True)

# Move tokens to GPU if available
tokens = {k: v.to(device) for k, v in tokens.items()}

# Make predictions
model.eval()  # Put the model in evaluation mode
with torch.no_grad():
    output = model(**tokens)

# Get the predicted labels
predictions = np.argmax(output.logits.cpu().numpy(), axis=2)
predicted_labels = [label_list[p] for p in predictions[0]]

# Print tokens and their predicted labels
print("\nInference Results:")
print(list(zip(tokenizer.convert_ids_to_tokens(tokens["input_ids"].cpu()[0]), predicted_labels)))


tokens = tokenizer.convert_ids_to_tokens(tokens["input_ids"].cpu()[0])
labels = predicted_labels  # from your model

drug = extract_drug(tokens, labels)
print(drug)
adr_symptoms = extract_adr(tokens, labels)
print(adr_symptoms)

