import logging

log = logging.getLogger("N25Q FLASH MEM")


class N25Q:
    _WRITE_ENABLE      = 0x06
    _WRITE_DISABLE     = 0x04
    _READ_STATUS       = (0x05, 1)
    _WRITE_STATUS      = 0x01
    _READ_LOCK         = 0xE8
    _WRITE_LOCK        = 0xE5
    _READ_FLAG_STATUS  = (0x70, 1)
    _CLEAR_FLAG_STATUS = 0x50
    _READ_ID           = (0x9e, 20)
    _READ_NV_CONFIG    = (0xB5, 2)
    _WRITE_NV_CONFIG   = 0xB1
    _READ              = 0x03
    _WRITE             = 0x02
    _BULK_ERASE        = 0xC7
    
    def __init__(self, dev, CTRL_TERM="N25Q_CTRL", DATA_TERM="N25Q_DATA"):
        self.dev = dev
        self.CTRL_TERM = CTRL_TERM
        self.DATA_TERM = DATA_TERM
        self.initialized = False
        
    def init_system(self):
        self.dev.set(self.CTRL_TERM, "pins.holdb", 1)
        self.dev.set(self.CTRL_TERM, "clk_divider", 4)
        id = self.get_id()
        log.info("READ_ID")
        for idx, x in enumerate(id):
            log.info("  %02d: 0x%02x" % (idx, x))
        if((id[0] != 0x20) or (id[1] != 0xBA)):
            log.error("Error Reading Flash Memory ID: " + str(id[:4]))
            self.initialized = False
            return id
        if(id[2] == 0x19):
            self.size = 2**(10+10+5)
            log.info("FLASH MEMORY SIZE CODE: 32MB")
        else:
            self.size = 0 # unknown
            log.info("UNKNOWN FLASH MEMORY SIZE CODE: 0x%02x" % (id[2]))

        # set to 4 byte addressing mode
        x = self.get_nv_config()
        x[0] = x[0] & 0xFE
        x[1] = 0xFF
        self.set_nv_config(x)
        self.enter_4_byte_address_mode()
        
        self.initialized = True
        return id
    
    def reset_system():
        self.dev.set(self.CTRL_TERM, "pins.holdb", 0)
        
    def cmd(self, cmd, num_read_bytes=0):
        """Performs the requested command on the flash memory.
        @param cmd: string or buffer with command and any additional writes
        @param num_read_bytes: number of bytes to read after command

        @returns: string as number of bytes
        """
        if type(cmd) is int:
            cmd0 = bytearray(1)
            cmd0[0] = cmd
            cmd = cmd0

        #log.info("N25Q CMD: " + str(["0x%02x" % x for x in cmd]) + " read=" + str(num_read_bytes))

        self.dev.set(self.CTRL_TERM, "csb1", 0)
            
        x = None
        try:
            self.dev.write(self.DATA_TERM, 0, cmd)
            if num_read_bytes > 0:
                x = bytearray(num_read_bytes)
                self.dev.read(self.DATA_TERM, 0, x)
        finally:
            self.dev.set(self.CTRL_TERM, "csb1", 1)
        return x

    def get_status(self):
        x = self.cmd(*self._READ_STATUS)[0]
        return dict(
            write_disabled      = (x >> 7) & 0x1,
            protect_bot_aligned = (x >> 5) & 0x1,
            block_protect       = ((x >> 2) & 0x7) + ((x >> 3) & 0x8),
            write_en_latch      = (x>>1) & 0x1,
            write_in_progress   = (x>>0) & 0x1,
        )

    def get_flags(self):
        return self.cmd(*self._READ_FLAG_STATUS)
    
    def get_id(self):
        return self.cmd(*self._READ_ID)

    def get_nv_config(self):
        return self.cmd(*self._READ_NV_CONFIG)
        
    def set_nv_config(self, config):
        self.write_enable()
        log.info("WRITING NV CONFIG: %02x %02x" % (config[0], config[1]))
        x = self.cmd(bytearray(chr(self._WRITE_NV_CONFIG)) + config, 0)
        self.write_enable(False)
        return x

    def write_enable(self, enable=True):
        if enable:
            self.dev.set(self.CTRL_TERM, "pins.wp", 1)
            self.cmd(self._WRITE_ENABLE)
        else:
            self.dev.set(self.CTRL_TERM, "pins.wp", 0)
            self.cmd(self._WRITE_DISABLE)
        

    def read(self, addr, num_bytes):
        c = bytearray([
            self._READ,
            (addr >> 23) & 0xFF,
            (addr >> 16) & 0xFF,
            (addr >>  8) & 0xFF,
            (addr >>  0) & 0xFF,
            ])
        return self.cmd(c, num_bytes)

    def write(self, addr, data):
        self.write_enable()
        c = bytearray(
            [self._WRITE,
             (addr >> 23) & 0xFF,
             (addr >> 16) & 0xFF,
             (addr >>  8) & 0xFF,
             (addr >>  0) & 0xFF,
            ]) + bytearray(data)
        self.cmd(c)
        self.write_enable(False)

    def bulk_erase(self):
        self.write_enable()
        self.cmd(self._BULK_ERASE)
        while self.get_status()["write_in_progress"]:
            pass
        self.write_enable(False)

    def subsector_erase(self, addr):
        """Erases a 4KB chuck. Any address in the 4KB chuck will work"""
        self.write_enable()
        self.cmd(self._BULK_ERASE)
        while self.get_status()["write_in_progress"]:
            pass
        self.write_enable(False)

    def enter_4_byte_address_mode(self):
        self.flash.write_enable()
        self.flash.cmd(0xb7)
        self.write_enable(False)

    def write_image(self, image, addr=0):
        addr0 = addr
        num_subsectors = len(image)/4096
        for subsector_idx in range(num_subsectors):
            self.subsector_erase(addr)
            for page in range(16):
                self.write(addr, image[addr:addr+256])
                addr += 256

        image0 = self.read(addr0, len(image))
        if(image != image0):
            raise Exception("Read back verification failed")
