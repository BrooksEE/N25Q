import math, struct

# File System ID - 32 bytes
# 4 bytes - Sync : 0xAAFF5500
# 2 bytes - version
# 26 bytes - reserved

# File Record - 32 bytes
#  8 bytes - filename
#  4 bytes - file address location
#  4 bytes - file length
#  2 bytes - file type
#  2 bytes - CRC
# 12 bytes - reserved

# File Types
file_types = dict(
    TYPE_UNKNOWN     = 0,
    TYPE_NATIVE_IMG  = 1,
    TYPE_OVERLAY_IMG = 2,
)

class FileSystem(dict):

    def __init__(self):
        dict.__init__(self)
        self.bs   = 2**12
        self.sync = '\xAA\xFF\x55\x00'
        self.version = 1

    def add_file(self, filename, data, file_type):
        self[filename[:8]] = dict(data=data, type=file_type)

    def pad(self, x, size=32):
        return x + ("\x00" * (size-len(x)))

    def file_record(self, k, v, addr):
        crc = sum(ord(y) for y in v["data"]) & 0xFFFF
        y = struct.pack('IIHH', addr, len(v["data"]), v["type"], crc)
        x = self.pad(self.pad(k[:8], 8) + y, 32)
        return x

    def dump(self, f):
        f.write(self.pad(self.sync + struct.pack("H", self.version), 32))
        record_count = 1
        num_header_blocks = int(math.ceil((len(self)+2) * 32.0 / self.bs)) # add 2 records for start record and stop sentinal
        addr = self.bs * num_header_blocks
        keys = self.keys()
        so_far = 32
        for k in keys:
            v = self[k]
            size = math.ceil(len(v["data"]) / self.bs) * self.bs
            f.write(self.file_record(k, v, addr))
            addr += size
            so_far += 32
        f.write("\x00" * (self.bs - (so_far % self.bs)))
        

        for k in keys:
            v = self[k]
            size = int(math.ceil(len(v["data"]) / float(self.bs)) * self.bs)
            f.write(v["data"])
            f.write("\x00" * (size - len(v["data"])))
