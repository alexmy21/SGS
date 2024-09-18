from transformers import AutoTokenizer
from torch.utils.data import DataLoader, Dataset

class GenericTokenizer:
    def __init__(self, model_name):
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    def tokenize(self, text):
        # Tokenize the text and return tokenized tokens as a string collection
        tokens = self.tokenizer.tokenize(text)
        return tokens
    
class BertTokenizerWrapper(GenericTokenizer):
    def __init__(self):
        super().__init__('bert-base-uncased')

class RobertaTokenizerWrapper(GenericTokenizer):
    def __init__(self):
        super().__init__('roberta-base')

class GPT2TokenizerWrapper(GenericTokenizer):
    def __init__(self):
        super().__init__('gpt2')
        
class TextDataset(Dataset):
    def __init__(self, texts):
        self.texts = texts
    
    def __len__(self):
        return len(self.texts)
    
    def __getitem__(self, idx):
        return self.texts[idx]
