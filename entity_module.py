import io
import redis
import torch

class Entity:
    def __init__(self, hllset, identifier, references=None):
        self.hllset = hllset
        self.identifier = identifier
        self.references = references if references is not None else []

    def add_reference(self, entity):
        self.references.append(entity)

    def save_to_redis(self, redis_client):
        serialized_tensor = self.serialize_tensor(self.hllset)
        redis_client.set(self.identifier, serialized_tensor)

    @staticmethod
    def load_from_redis(redis_client, identifier):
        serialized_tensor = redis_client.get(identifier)
        if serialized_tensor is None:
            return None
        hllset = Entity.deserialize_tensor(serialized_tensor).cuda()
        return Entity(hllset, identifier)

    @staticmethod
    def serialize_tensor(tensor):
        buffer = io.BytesIO()
        torch.save(tensor, buffer)
        return buffer.getvalue()

    @staticmethod
    def deserialize_tensor(buffer):
        buffer = io.BytesIO(buffer)
        return torch.load(buffer)

def elementwise_union(tensor1, tensor2):
    assert tensor1.shape == tensor2.shape, "Tensors must have the same shape"
    return tensor1 | tensor2

def elementwise_intersection(tensor1, tensor2):
    assert tensor1.shape == tensor2.shape, "Tensors must have the same shape"
    return tensor1 & tensor2

def top_index_reversed_binary(tensor):
    assert tensor.dtype == torch.int64, "Tensor must be of dtype torch.int64"
    result = torch.zeros(tensor.shape[0], dtype=torch.int64, device=tensor.device)
    for i in range(tensor.shape[0]):
        row = tensor[i]
        for j in range(tensor.shape[1]):
            if row[j] != 0:
                binary_str = bin(row[j].item())[2:].zfill(64)  # Convert to binary string and pad to 64 bits
                reversed_binary_str = binary_str[::-1]  # Reverse the binary string
                top_index = reversed_binary_str.find('1')  # Find the index of the highest set bit
                result[i] = max(result[i], top_index)
    return result