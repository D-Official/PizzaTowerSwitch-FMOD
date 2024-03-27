# This script is used to decrypt the bins from the releases tab.
# For more info check out the readme
import os
import time

def find_only_ext_file(path, ext):
    ext_files = []
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith("." + ext):
                ext_files.append(os.path.join(root, file))
    if len(ext_files) != 1:
        return None
    return ext_files[0]

def extract_sr_number(filename):
    sr_ind = filename.find("SR_")
    if sr_ind == -1:
        return 999
        
    num_str = ""
    for char in filename[sr_ind + 3:]:
        if not char.isdigit():
            break
        num_str += char
    if num_str == "":
        return 999
    return int(num_str)
    
def read_file_as_bytes(file_path):
    with open(file_path, 'rb') as file:
        return bytearray(file.read())
        
def duplicate_list_until_length_matches(original_list, target_length):
    result_list = original_list.copy()
    while len(result_list) < target_length:
        result_list += original_list
    return result_list[:target_length]
        
encrypted_path = find_only_ext_file(os.getcwd(), "bin")
data_path = find_only_ext_file(os.getcwd(), "win")

if (encrypted_path == None or data_path == None):
    print("Make sure the folder this script is ran in has exactly one .bin file and exactly one .win file.")
    print("(Will not work if there's two of the same extension, because I don't know which one you want!)")
    input("")
    quit()
    

print("Reading files")

sr_number = extract_sr_number(os.path.basename(encrypted_path))

encrypted_bytes = read_file_as_bytes(encrypted_path)
data_bytes = read_file_as_bytes(data_path)[::2] # [::2] removes half of the bytes

data_big = duplicate_list_until_length_matches(data_bytes, len(encrypted_bytes))

print("Decrypting (This could take a while...)")

nsp_bytes = [byte1 ^ byte2 for byte1, byte2 in zip(encrypted_bytes, data_big)]

print("Saving .nsp")

with open(f"Pizza Tower SR {sr_number} [05000FD261232000][v0].nsp", 'wb') as file:
    file.write(bytes(nsp_bytes))

print("Done!")
