import torch
import numpy as np
import hashlib
import os
from transformers import GPT2Tokenizer, GPT2LMHeadModel

class ExtendedGPT2Tokenizer(GPT2Tokenizer):
    
    def __init__(self, vocab_file, merges_file, tensor_0_path='', tensor_1_path='', tensor_2_path='', tensor_3_path='', *args, p=4, **kwargs):
        super().__init__(vocab_file, merges_file, *args, **kwargs)
        self.p = p
        self.num_bins = 2 ** p
        
        # Initialize tensor_0
        if tensor_0_path:
            self.tensor_0 = torch.load(tensor_0_path)
        else:
            self.tensor_0 = {}

        # Initialize tensor_1
        if tensor_1_path:
            self.tensor_1 = torch.load(tensor_1_path)
        else:
            self.tensor_1 = torch.zeros((0, 2), dtype=torch.int64)  # Initialize with shape (0, 2)

        # Initialize tensor_2
        if tensor_2_path:
            self.tensor_2 = torch.load(tensor_2_path)
        else:
            self.tensor_2 = torch.zeros((0, self.num_bins), dtype=torch.int64)  # Initialize with shape (0, num_bins)

        # Initialize tensor_3
        if tensor_3_path:
            self.tensor_3 = torch.load(tensor_3_path)
        else:
            self.tensor_3 = torch.zeros((32, self.num_bins, 0), dtype=torch.int64)  # Initialize with shape (32, num_bins, 0)

    def hash_token_id(self, token_id):
        # Use a consistent hash function
        return int(hashlib.md5(str(token_id).encode()).hexdigest(), 16) & 0xffffffff

    def calculate_bin_and_zeros(self, hash_value):
        bin_number = hash_value >> (32 - self.p)
        trailing_zeros = (hash_value & -hash_value).bit_length() - 1
        return bin_number, trailing_zeros

    def convert_to_hashes(self, token_ids):
        return [self.hash_token_id(token_id) for token_id in token_ids]
    
    def tensor_sha1(self, tensor):
        tensor_binary = tensor.numpy().tobytes()
        return hashlib.sha1(tensor_binary).hexdigest()

    def update_tensors(self, token_ids):
        # Update tensor_1
        token_hashes = self.convert_to_hashes(token_ids)
        self.tensor_1 = torch.stack((torch.tensor(token_ids, dtype=torch.int64), torch.tensor(token_hashes, dtype=torch.int64)), dim=1)

        # Update tensor_2 and tensor_3
        new_tensor_2 = torch.zeros(self.num_bins, dtype=torch.int64)
        new_tensor_3 = torch.zeros((32, self.num_bins, len(token_ids)), dtype=torch.int64)

        for i, token_hash in enumerate(token_hashes):
            bin_number, trailing_zeros = self.calculate_bin_and_zeros(token_hash)
            new_tensor_2[bin_number] |= trailing_zeros
            new_tensor_3[trailing_zeros, bin_number, i] = token_hash
            print(f"new_tensor_3[{trailing_zeros}, {bin_number}, {i}] = {token_hash}")

        # Calculate SHA1 of binary representation of new_tensor_2
        sha1_hash = self.tensor_sha1(new_tensor_2)

        # Get integer for given SHA1 from tensor_0
        if sha1_hash not in self.tensor_0:
            self.tensor_0[sha1_hash] = len(self.tensor_0) + 1
        hllset_id = self.tensor_0[sha1_hash]

        # Ensure tensor_2 has enough rows
        if hllset_id > self.tensor_2.size(0):
            new_rows = hllset_id - self.tensor_2.size(0)
            self.tensor_2 = torch.cat((self.tensor_2, torch.zeros((new_rows, self.num_bins), dtype=torch.int64)), dim=0)

        # Update tensor_2 by applying bitwise OR to existing values
        self.tensor_2[hllset_id - 1] |= new_tensor_2        
        
        # Print shapes and data types before concatenation
        print("tensor_3 shape:", self.tensor_3.shape)
        print("new_tensor_3 shape:", new_tensor_3.shape)
        print("tensor_3 dtype:", self.tensor_3.dtype)
        print("new_tensor_3 dtype:", new_tensor_3.dtype)
        
        # Update tensor_3
        if self.tensor_3.size(2) > 0:
            self.tensor_3 = torch.cat((self.tensor_3, new_tensor_3), dim=2)
        else:
            self.tensor_3 = new_tensor_3
            
        print("tensor_1:", self.tensor_1)
        print("tensor_3:", self.tensor_3)


        return sha1_hash, hllset_id, token_hashes

    def print_tensors(self):
        print("tensor_0:", self.tensor_0)
        print("tensor_1:", self.tensor_1)
        print("tensor_2:", self.tensor_2)
        print("tensor_3:", self.tensor_3)

    def tokenize_text(self, text):
        token_ids = self.encode(text)
        return token_ids

    def save_tensors(self, directory):
        if not os.path.exists(directory):
            os.makedirs(directory)
        
        torch.save(self.tensor_0, os.path.join(directory, 'tensor_0.pt'))
        torch.save(self.tensor_1, os.path.join(directory, 'tensor_1.pt'))
        torch.save(self.tensor_2, os.path.join(directory, 'tensor_2.pt'))
        torch.save(self.tensor_3, os.path.join(directory, 'tensor_3.pt'))
        
def get_tensor_values(tensor, bin, zeros):
    return tensor[zeros, bin, :].tolist()