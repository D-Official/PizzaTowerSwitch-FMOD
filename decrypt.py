# This script is used to decrypt the bins from the releases tab.
# For more info check out the readme

def read_file_as_bytes(file_path):
    with open(file_path, 'rb') as file:
        return bytearray(file.read())
        
def duplicate_list_until_length_matches(original_list, target_length):
    result_list = original_list.copy()
    while len(result_list) < target_length:
        result_list += original_list
    return result_list[:target_length]
        
encrypted_path = 'pizza_tower_switch_port_encrypted.bin'
data_path = 'data.win'

print("Reading files")

encrypted_bytes = read_file_as_bytes(encrypted_path)
data_bytes = read_file_as_bytes(data_path)[::2] # [::2] removes half of the bytes

data_big = duplicate_list_until_length_matches(data_bytes, len(encrypted_bytes))

print("Decrypting")

nsp_bytes = [byte1 ^ byte2 for byte1, byte2 in zip(encrypted_bytes, data_big)]

print("Saving .nsp")

with open("Pizza Tower v1.0.5952 SR 4 [05000FD261232000][v0].nsp", 'wb') as file:
    file.write(bytes(nsp_bytes))

print("Done!")