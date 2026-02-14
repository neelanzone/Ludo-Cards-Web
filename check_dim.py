import struct

def get_png_dimensions(file_path):
    with open(file_path, 'rb') as f:
        # PNG signature
        f.seek(16)
        width = struct.unpack('>I', f.read(4))[0]
        height = struct.unpack('>I', f.read(4))[0]
        return width, height

try:
    w, h = get_png_dimensions('assets/cards/Attack01.png')
    print(f"Dimensions: {w}x{h}")
except Exception as e:
    print(f"Error: {e}")
