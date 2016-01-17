import math, struct

# File System ID - 32 bytes
# 8 bytes - Sync : "BROOKSEE"
# 4 bytes - version
# 4 bytes - length of fs header in bytes
# 16 bytes - reserved

# File Record - 32 bytes
#  8 bytes - filename
#  4 bytes - file address location
#  4 bytes - file length
#  2 bytes - file type
#  2 bytes - CRC
#  2 bytes - width
#  2 bytes - height
#  8 bytes - reserved

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
        self.sync = 'BROOKSEE'
        self.version = 1

    def add_file(self, filename, data, file_type, width=None, height=None):
        x = dict(data=data, type=file_type)
        if width:
            x["width"] = width
        if height:
            x["height"] = height
        self[filename[:8]] = x

    def pad(self, x, size=32):
        return x + ("\x00" * (size-len(x)))

    def file_record(self, k, v, addr):
        crc = 0
        for y in v["data"]:
            try:
                crc += y
            except:
                crc += ord(y)
        crc = crc & 0xFFFF
        y = struct.pack('IIHH', addr, len(v["data"]), v["type"], crc)
        if "width" in v:
            y += struct.pack("H", v["width"])
        else:
            y += "\x00\x00"
        if "height" in v:
            y += struct.pack("H", v["height"])
        else:
            y += "\x00\x00"
        x = self.pad(self.pad(k[:8], 8) + y, 32)
        return x

    def dump(self, f):
        num_header_blocks = int(math.ceil((len(self)+2) * 32.0 / self.bs)) # add 2 records for start record and stop sentinal
        header_len = num_header_blocks * self.bs
        f.write(self.pad(self.sync + struct.pack("II", self.version, header_len), 32))
        record_count = 1
        addr = self.bs * num_header_blocks
        keys = self.keys()
        so_far = 32
        for k in keys:
            v = self[k]
            size = int(math.ceil(len(v["data"]) / float(self.bs)) * self.bs)
            f.write(self.file_record(k, v, addr))
            v["__size"] = size
            addr += size
            so_far += 32
        f.write("\x00" * (self.bs - (so_far % self.bs)))
        for k in keys:
            v = self[k]
            f.write(v["data"])
            f.write("\x00" * (v["__size"] - len(v["data"])))
            print v["__size"], len(v["data"])

    def decode_file_record(self, record):
        name = record[:8].replace("\x00","")
        addr, size, type, crc = struct.unpack("IIHH", record[8:20])
        return dict(name=name, addr=addr, size=size, type=type, crc=crc)

    @classmethod
    def load(cls, f):
        self = cls()
        raw = f.read()
        header = self.decode_file_record(raw[:32])
        if(header["name"] != "BROOKSEE"):
            raise Exception("UNKNOWN FILESYSTEM")
        print "HEADER=", header
        records = []
        count = 1
        while True:
            record = self.decode_file_record(raw[32*count:32*(count+1)])
            if record["addr"] == 0:
                break
            print count, " RECORD=", record
            count += 1
        
            records.append(record)
        for record in records:
            self.add_file(record["name"], raw[record["addr"]:record["addr"]+record["size"]], record["type"])
            self[record["name"]]["addr"] = record["addr"]
            self[record["name"]]["size"] = record["size"]
            
        return self
    
