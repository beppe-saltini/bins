import struct, zlib

def create_png(filename, r, g, b, size):
    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)

    sig = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0))
    raw = b''
    for _ in range(size):
        raw += b'\x00' + bytes([r, g, b]) * size
    idat = chunk(b'IDAT', zlib.compress(raw, 9))
    iend = chunk(b'IEND', b'')

    with open(filename, 'wb') as f:
        f.write(sig + ihdr + idat + iend)
    print(f"  {filename} ({size}x{size})")

print("Generating icons...")
create_png('Resources/GreenBin@2x.png', 76, 175, 80, 120)
create_png('Resources/GreenBin@3x.png', 76, 175, 80, 180)
create_png('Resources/BlackBin@2x.png', 30, 30, 30, 120)
create_png('Resources/BlackBin@3x.png', 30, 30, 30, 180)
print("Done.")
