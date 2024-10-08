import torch
import numpy as np
import hashlib
import mmh3
import os
from transformers import GPT2Tokenizer, GPT2LMHeadModel
from sklearn.metrics.pairwise import cosine_similarity

class ExtendedGPT2Tokenizer(GPT2Tokenizer):
    """
    ExtendedGPT2Tokenizer
    This class extends the GPT2Tokenizer to include additional functionalities for handling tensors and performing various operations on them.
    Attributes:
        p (int): The power of 2 used to determine the number of bins.
        int_bit (int): The bit length of integers used in hashing.
        num_bins (int): The number of bins calculated as 2^p.
        tensor_0 (dict): A dictionary to store tensor_0 data.
        tensor_0_keys (list): A list of keys from tensor_0.
        tensor_0_values (torch.Tensor): A tensor of values from tensor_0.
        tensor_1 (torch.Tensor): A tensor to store tensor_1 data.
        tensor_2 (torch.Tensor): A tensor to store tensor_2 data.
    Methods:
        __init__(self, vocab_file, merges_file, tensor_0_path='', tensor_1_path='', tensor_2_path='', *args, p=4, int_bit=32, **kwargs):
            Initializes the ExtendedGPT2Tokenizer with the given parameters and loads tensors if paths are provided.
        zeros(self, n):
            Returns the minimum of n+1 and int_bit - p.
        update_tensors(self, token_ids):
            Updates tensor_1 with new entries based on the given token IDs and returns the new tensor and double values.
        tensor_to_hlltensor(self, tensor):
            Converts a tensor to an HLL tensor and updates tensor_0 and tensor_2.
        hlltensor_to_tensor(self, hllset):
            Converts an HLL set to a tensor slice.
        update_tensor_0(self, hlltensor):
            Updates tensor_0 with the SHA1 hash of the HLL tensor and returns the ID and SHA1 hash.
        update_tensor_2(self, id, hlltensor):
            Updates tensor_2 with the given ID and HLL tensor.
        get_hllset_id(self, hllset):
            Returns the ID of the HLL set if found in tensor_0, otherwise returns None.
        tokenize_text(self, text):
            Tokenizes the given text and returns the token IDs.
        search(self, query, threshold):
            Searches for the query in the tensors and returns the indices of matches above the given threshold.
        generate_text(self, tokens, num_suggestions=3):
            Generates text suggestions based on the given tokens and returns the suggestions.
        evaluate_generated_texts(self, generated_texts, communities):
            Evaluates the generated texts against the given communities and returns the results.
        format_generated_texts(self, suggestions):
            Formats the generated text suggestions and returns the formatted string.
        save_tensors(self, directory):
            Saves the tensors to the specified directory.
        sequence_to_integer(self, old_in, new_zeros):
            Converts a sequence of zeros to an integer.
        sequence_from_integer(self, n):
            Converts an integer to a sequence of bit indices.
        calculate_bin_and_zeros(self, hash_value):
            Calculates the bin number and trailing zeros for the given hash value.
        hash_token_id(self, token_id):
            Hashes the given token ID using MurmurHash3 (64-bit).
        hash_token_ids(self, token_ids):
            Hashes the given list of token IDs.
        tensor_sha1(self, tensor):
            Calculates the SHA1 hash of the given tensor.
        get_tensor_0(self, key):
            Returns the key and value from tensor_0 for the given key.
        print_tensors(self):
            Prints the tensors.
        print_tensor_1(self, tensor):
            Prints tensor_1.
        get_tensor_values(self, tensor, bin, zeros):
            Returns the values from the tensor for the given bin and zeros.
    """
    
    def __init__(self, vocab_file, merges_file, 
                tensor_0_path='', 
                tensor_1_path='', 
                tensor_2_path='',
                *args, 
                p=4,
                int_bit=32, 
                **kwargs):
        super().__init__(vocab_file, merges_file, *args, **kwargs)
        
        self.p = p
        self.int_bit = int_bit
        self.num_bins = 2 ** p

        # Initialize tensor_0
        if tensor_0_path:
            self.tensor_0 = torch.load(tensor_0_path, weights_only=True) 
        else:
            self.tensor_0 = {}
        
        # Store keys and values separately
        self.tensor_0_keys = list(self.tensor_0.keys())
        self.tensor_0_values = torch.tensor(list(self.tensor_0.values()))

        # Initialize tensor_1
        if tensor_1_path:
            self.tensor_1 = torch.load(tensor_1_path, weights_only=True)
        else:
            self.tensor_1 = torch.zeros((0, 3), dtype=torch.int64)  # Initialize with shape (0, 2)

        # Initialize tensor_2
        if tensor_2_path:
            self.tensor_2 = torch.load(tensor_2_path, weights_only=True)
        else:
            self.tensor_2 = torch.zeros((0, self.num_bins + 1), dtype=torch.int64)  # Initialize with shape (0, num_bins)

# ====================================================================
    def zeros(self, n):
        return min(n + 1, self.int_bit - self.p)
    
    def update_tensors(self, token_ids):
        # Convert token IDs to hashes
        hashes = self.hash_token_ids(token_ids)

        new_entries     = []
        double_values   = []
        # Initialize with -1 to indicate uninitialized state
        new_tensor_1    = torch.full((0, 3), 0.0, dtype=torch.float64)  
        
        for token_id, hash_value in zip(token_ids, hashes):
            bin_number, trailing_zeros = self.calculate_bin_and_zeros(hash_value)
            trailing_zeros = self.zeros(trailing_zeros)
            # print(f"hash_value: {hash_value}; bin_number: {bin_number}; trailing_zeros: {trailing_zeros}")  # Debug print
            # Adding 1 to indicate the presence of the token
            double_value = float(f"{bin_number}.{trailing_zeros}") 
            double_values.append(double_value)
            print(f"Generated double_value: {double_value}")  # Debug print
            # Update tensor_1
            if hash_value not in self.tensor_1[:, 1]:
                new_entry = torch.tensor([[token_id, hash_value, double_value]], dtype=torch.float64)
                new_entries.append(new_entry)

        if new_entries:
            new_tensor_1 = torch.cat(new_entries, dim=0)
            self.tensor_1 = torch.cat((self.tensor_1, new_tensor_1), dim=0)

        return new_tensor_1, double_values
        
    def tensor_to_hlltensor(self, tensor):
        hlltensor = torch.full((self.num_bins,), 0, dtype=torch.int64)
        for row in tensor:
            token_id, hash_value, double_value = row
            # Convert double_value to string and extract bin_number and zeros_number
            double_str = f"{double_value}" 
            bin_number, zeros_number = map(int, double_str.split('.'))
            zeros_old = hlltensor[bin_number].item()
            # print(f"zeros_old: {zeros_old}; zeros_number: {zeros_number}")  # Debug print
            try:
                # zeros_number = self.zeros(zeros_number)
                hlltensor[bin_number] = self.sequence_to_integer(zeros_old, [zeros_number])
            except OverflowError:
                print(f"Overflow error for bin_number {bin_number} with zeros_old {zeros_old} and zeros_number {zeros_number}")
                hlltensor[bin_number] = torch.iinfo(torch.int64).max  # Set to max value to indicate overflow
                
        # Update tensor_0 with the SHA1 hash of hlltensor
        id, sha1 = self.update_tensor_0(hlltensor)
        
        self.update_tensor_2(id, hlltensor)
        
        return id, sha1, hlltensor
    
    
    def hlltensor_to_tensor(self, hllset):
        """
        Converts an HLL set to a tensor.

        This method takes an HLL (HyperLogLog) set and converts it into a PyTorch tensor.
        The conversion process involves transforming the HLL set representation into a slice of tensor_1,
        presenting all posible token_ids and token_hashes that match the values in the bins of hllset.
        Each bin can represent multiple token_hashes. The hllset encodes token_hash as bin_number and trailing_zeros.
        Important note: extracted tensor slice may contain references to tokens that were not in original dataset
        from which this hllset was built.

        Parameters:
        -----------
        hllset : Any
            The HLL set to be converted. The exact type and structure of the HLL set
            depend on the implementation details of the HLL algorithm used.

        Returns:
        --------
        torch.Tensor
            A PyTorch tensor representing the HLL set. The tensor format will be suitable
            for further tensor operations and calculations.

        Example:
        --------
        >>> hllset = some_hll_set_representation
        >>> tensor = tokenizer.hlltensor_to_tensor(hllset)
        >>> print(tensor)
        tensor([...])
        """
        tensor_slice = []
        for bin_number in range(self.num_bins):
            bin_value = hllset[bin_number]
            # Skip if bin_value is 0, it was not touched and has no assigned hashes.
            if bin_value == 0:
                continue
            
            zeros_array = self.sequence_from_integer(bin_value.item())
            for zeros_number in zeros_array:                                  
                double_value = float(f"{bin_number}.{zeros_number}")                    
                # print(f"Processing double_value: {double_value}")  # Debug print
                                    
                # Create a boolean mask where each element is True if the corresponding 
                # element in the tensor_1 column 2 is equal to double_value
                mask = self.tensor_1[:, 2] == float(double_value)

                # Use the boolean mask to filter and retrieve all matching rows
                matching_rows = self.tensor_1[mask]

                # Check if there are any matching rows and append them to tensor_slice
                if matching_rows.size(0) > 0:
                    tensor_slice.append(matching_rows)
                    # print(f"Matching rows for {double_value}: {matching_rows}")  # Debug print
                else:
                    print(f"NOT matching rows for {double_value}: {matching_rows}")  # Debug print
                        
        # return torch.cat(tensor_slice, dim=0) if tensor_slice else torch.zeros((0, 3), dtype=torch.float64)
        result_tensor = torch.cat(tensor_slice, dim=0) if tensor_slice else torch.zeros((0, 3), dtype=torch.float64)
        # print(f"Final tensor slice: {result_tensor}")  # Debug print
        return result_tensor
    
    def update_tensor_0(self, hlltensor):
        
        # Calculate SHA1 of binary representation of new_tensor_2
        sha1_hash = self.tensor_sha1(hlltensor)

        # Get integer for given SHA1 from tensor_0
        if sha1_hash not in self.tensor_0:
            self.tensor_0[sha1_hash] = len(self.tensor_0) + 1
        return self.tensor_0[sha1_hash], sha1_hash
    
    def update_tensor_2(self, id, hlltensor):
        # Create a new tensor with the ID and hlltensor
        id_tensor = torch.tensor([id], dtype=torch.int64)
        hlltensor_with_id = torch.cat((id_tensor, hlltensor), dim=0).unsqueeze(0)  # Add a new dimension at the beginning
        # print(f"shape tensor_2: {self.tensor_2}; hlltensor_with_id: {hlltensor_with_id}")  # Debug print
        # Update tensor_2
        self.tensor_2 = torch.cat((self.tensor_2, hlltensor_with_id), dim=0)
            
    def get_hllset_id(self, hllset):
        # Compute SHA1 hash of hllset
        hllset_bytes = hllset.numpy().tobytes()
        hllset_sha1 = hashlib.sha1(hllset_bytes).hexdigest()
        
        # Convert SHA1 hash to a float
        hllset_sha1_float = float.fromhex(hllset_sha1)
        
        # Search for the float in tensor_0
        indices = torch.nonzero(torch.eq(self.tensor_0[:, 1], hllset_sha1_float), as_tuple=False)
        
        if indices.numel() == 0:
            return None  # Return None if the SHA1 hash is not found in tensor_0
        else:
            return indices[0].item()  # Return the index of the first match

    def tokenize_text(self, text):
        return self.encode(text)
    
    def search(self, query, threshold):
        # Tokenize the query
        token_ids = self.tokenize(query)

        # Convert tokens to hashes
        query_hashes = self.hash_token_ids(token_ids)

        # Create HLL set vector for the query
        query_hllset = np.full(self.num_bins, 0, dtype=np.int64)
        for hash_value in query_hashes:
            bin_number, trailing_zeros = self.calculate_bin_and_zeros(hash_value)
            trailing_zeros = self.zeros(trailing_zeros)
            # print(f"hash_value: {hash_value}; bin_number: {bin_number}; trailing_zeros: {trailing_zeros}")  # Debug print
            zeros_old = query_hllset[bin_number].item()
            query_hllset[bin_number] = self.sequence_to_integer(zeros_old, [trailing_zeros])

        # Convert query_hllset to a torch.Tensor if it is a numpy.ndarray
        if isinstance(query_hllset, np.ndarray):
            query_hllset = torch.tensor(query_hllset, dtype=torch.int64)
            
        dummy_id = torch.tensor([0], dtype=torch.int64)
        
        # Ensure dummy_id and query_hllset have the same number of dimensions
        dummy_id = dummy_id.unsqueeze(1) if dummy_id.dim() == 1 else dummy_id
        
        print(f"dummy_id: {dummy_id.shape}; query_hllset: {query_hllset.shape}")  # Debug print
        
        # Concatenate the tensors
        query_hllset_with_id = torch.cat((dummy_id, query_hllset.unsqueeze(0)), dim=1)   # .unsqueeze(0) 
        print(f"query_hllset_with_id: {query_hllset_with_id}")  # Debug print
        
        # Compute cosine similarity
        similarities = cosine_similarity(query_hllset_with_id.numpy(), self.tensor_2.numpy())

        return [
            i
            for i, similarity in enumerate(similarities[0])
            if similarity > threshold
        ]
        
    def get_related_tokens(self, indices):
        # Step 1: Call the search function to get the indices of relevant HLL sets
        # indices = self.search(query, threshold)
        
        # Step 2: Retrieve the HLL sets from tensor_2 using the indices
        relevant_hllsets = self.tensor_2[indices]
        
        # Step 3: Collect token IDs from tensor_1
        token_ids = []
        for hllset in relevant_hllsets:
            print(f"Processing hllset (1): {hllset}")  # Debug print
            # Extract the last 16 elements
            hllset = hllset[-self.num_bins:]
            print(f"Processing hllset (2): {hllset}")  # Debug print

            # Apply hlltensor_to_tensor to retrieve the slice of tensor_1
            tensor_slice = self.hlltensor_to_tensor(hllset)
            
            # Extract token_id from each row in the tensor_slice
            for row in tensor_slice:
                token_id = row[0].item()
                token_ids.append(token_id)
        
        # Step 4: Retrieve tokens associated with the token IDs
        tokens = [self.decode([token_id]) for token_id in token_ids]
        
        return tokens

    def generate_text(self, tokens, num_suggestions=3):
        
        model = GPT2LMHeadModel.from_pretrained('gpt2')
        tokenizer = GPT2Tokenizer.from_pretrained('gpt2')
        
        # Validate tokens input
        if not isinstance(tokens, (str, list, tuple)):
            raise ValueError("Input tokens should be a string, a list/tuple of strings, or a list/tuple of integers.")
        
        input_ids = tokenizer.encode(tokens, return_tensors='pt')
        
        # Check if input_ids is empty
        if input_ids.numel() == 0:
            raise ValueError("Input tokens resulted in an empty tensor.")    

        # Create attention mask
        attention_mask = torch.ones(input_ids.shape, dtype=torch.long)
        
        outputs = model.generate(
            input_ids,
            attention_mask=attention_mask,
            max_length=50, 
            num_return_sequences=num_suggestions, 
            no_repeat_ngram_size=2,
            num_beams=num_suggestions,  # Enable beam search
            pad_token_id=tokenizer.eos_token_id  # Set pad_token_id to eos_token_id
            )
        
        return [tokenizer.decode(output, skip_special_tokens=True, clean_up_tokenization_spaces=True) for output in outputs]

    def evaluate_generated_texts(self, generated_texts, communities):
        results = []
        community_hllsets = []

        # Retrieve HLL sets for each community
        for hllset_id in communities:
            print(f"hllset_id: {hllset_id}")
            if hllset_id not in self.tensor_0:
                raise ValueError(f"HLL set ID {hllset_id} not found in tensor_0.")
            index = self.tensor_0[hllset_id]
            print(f"index: {index}")
            community_hllset = self.tensor_2[index - 1]
            print(f"community_hllset: {community_hllset}")
            community_hllset = community_hllset[-self.num_bins:]
            community_hllsets.append(community_hllset)

        for text in generated_texts:
            # Tokenize and convert to HLL set
            token_ids = self.tokenize(text)
            text_hashes = self.hash_token_ids(token_ids)
            text_hllset = np.zeros(self.num_bins, dtype=np.int64)
            for hash_value in text_hashes:
                bin_number, trailing_zeros = self.calculate_bin_and_zeros(hash_value)
                trailing_zeros = self.zeros(trailing_zeros)
                text_hllset[bin_number] = max(text_hllset[bin_number], trailing_zeros)
            
            # Compute cosine similarity with community HLL sets
            similarities = cosine_similarity([text_hllset], community_hllsets)
            best_match_idx = np.argmax(similarities)
            best_match_similarity = similarities[0][best_match_idx]
            best_matching_community = communities[best_match_idx]
            
            results.append((text, best_matching_community, best_match_similarity))
        
        return results
    
    def format_generated_texts(self, suggestions):
        formatted_suggestions = "\nGenerated text suggestions:\n"
        for i, suggestion in enumerate(suggestions, 1):
            formatted_suggestions += f"Suggestion {i}:\n{suggestion}\n\n"
        return formatted_suggestions
 
    def save_tensors(self, directory):
        if not os.path.exists(directory):
            os.makedirs(directory)        
        torch.save(self.tensor_0, os.path.join(directory, 'tensor_0.pt'))
        torch.save(self.tensor_1, os.path.join(directory, 'tensor_1.pt'))
        torch.save(self.tensor_2, os.path.join(directory, 'tensor_2.pt'))
    
    # ===================================================================
    # Support
    # ===================================================================
    
    def sequence_to_integer(self, old_in, new_zeros):
        # Initialize result based on old_in
        result = old_in
        
        # Set bits for each index in new_zeros
        for index in new_zeros:
            result |= (1 << index)
        
        return result
     
    def sequence_from_integer(self, n):
        bit_indices = []
        index = 0
        while n > 0:
            if n & 1 == 1:
                bit_indices.append(index)
            n >>= 1
            index += 1
        return bit_indices

    def calculate_bin_and_zeros(self, hash_value):
        bin_number = hash_value >> (self.int_bit - self.p)
        trailing_zeros = (hash_value & -hash_value).bit_length() - 1
        return bin_number, trailing_zeros
   
    def hash_token_id(self, token_id):
        # Use MurmurHash3 (64-bit)
        return mmh3.hash64(str(token_id))[0] & 0xffffffff

    def hash_token_ids(self, token_ids):
        return [self.hash_token_id(token_id) for token_id in token_ids]
    
    def tensor_sha1(self, tensor):
        tensor_binary = tensor.numpy().tobytes()
        return hashlib.sha1(tensor_binary).hexdigest()
    
# ==============================================================================
     
    def get_tensor_0(self, key):        
        if key not in self.tensor_0:
            raise KeyError(f"Key {key} not found in tensor0")
        
        index = self.tensor_0_keys.index(key)
        value = self.tensor_0_values[index].item()
        return key, value
 
    def print_tensors(self):
        print("tensor_0:", self.tensor_0)
        # print("tensor_1:", self.tensor_1)
        # print("tensor_2:", self.tensor_2)
        self.print_tensor_1(self.tensor_1)
       
    def print_tensor_1(self, tensor):
        if tensor is None:
            tensor = self.tensor_1
            
        print("tensor_1:")
        for i in range(tensor.size(0)):
            token_id = int(tensor[i, 0])
            token_hash = int(tensor[i, 1])
            double_value = float(tensor[i, 2])
            print(f"[{token_id},\t{token_hash},\t{double_value}]")
              
    def get_tensor_values(self, tensor, bin, zeros):
        return tensor[zeros, bin, :].tolist()