import re
from transformers import AutoTokenizer

def clean_text(text):
    # Remove HTML tags
    text = re.sub(r'<.*?>', '', text)
    # Remove special characters (except for basic punctuation)
    text = re.sub(r'[^a-zA-Z0-9\s.,!?\'"]', '', text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    # Decode escape sequences
    text = text.encode().decode('unicode_escape')
    return text

def parse_decoded_strings(decoded_strings):
    # Flatten the list of lists
    flat_list = [clean_text(item) for sublist in decoded_strings for item in sublist]
    # Clean each string
    cleaned_strings = [clean_text(s) for s in flat_list]
    return cleaned_strings[0].split(",")

def tokenize_text(texts, model_name="openai-community/gpt2", max_length=1024):
    # Initialize the tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name)
        
    # Clean and tokenize the input texts with truncation
    tokenized_texts = [tokenizer.encode(clean_text(text), add_special_tokens=True, max_length=max_length, truncation=True) for text in texts]
    
    return tokenized_texts
    

def decode_tokens(token_ids, model_name="openai-community/gpt2"):
    # Initialize the tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    # Decode the token IDs back to text
    decoded_texts = [tokenizer.decode(ids, skip_special_tokens=True) for ids in token_ids]
    
    return decoded_texts

def get_vocab(model_name="openai-community/gpt2"):
    # Initialize the tokenizer
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    # Get the vocabulary
    vocab = tokenizer.get_vocab()
    
    # Return the vocabulary items
    return vocab.items()