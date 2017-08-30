import logging, sys, time

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
    _READ_CONFIG       = (0x85, 1)
    _WRITE_CONFIG      = 0x81
    _READ              = 0x03
    _READ_QUAD         = 0x6B
    _WRITE             = 0x02
    _BULK_ERASE        = 0xC7
    _ENTER_4_BYTE_ADDRESS_MODE = 0xB7
    _SUBSECTOR_ERASE   = 0x20
    def __init__(self, dev, CTRL_TERM="N25Q_CTRL", DATA_TERM="N25Q_DATA", quad_mode_read_ok=True):
        self.dev = dev
        self.CTRL_TERM = CTRL_TERM
        self.DATA_TERM = DATA_TERM
        self.initialized = False
        self.quad_mode_read_ok = quad_mode_read_ok

    def disable_quad_read(self):
        self.quad_ok = False
        
    def init_system(self):
        self.dev.set(self.CTRL_TERM, "mode.quad", 0)
        self.dev.set(self.CTRL_TERM, "pins.holdb", 1)
        self.dev.set(self.CTRL_TERM, "clk_divider", 4)
        id = self.get_id()
        log.info("READ_ID")
        for idx, x in enumerate(id):
            log.debug("  %02d: 0x%02x" % (idx, x))
        if((id[0] != 0x20) or (id[1] != 0xBA)):
            log.error("Error Reading Flash Memory ID: 0x%02x 0x%02x. Should be 0x20 0xba" % (id[0], id[1]))
            log.error("  ID=" + " ".join("%02x" % h for h in id))
            self.initialized = False
            raise Exception("Error Reading Flash Memory ID")
        self.size = 2**id[2]
        self.num_addr_bits = id[2]
        log.info("FLASH MEMORY SIZE CODE: %d MB" % (self.size/1e6))

        # set to 4 byte addressing mode if num_addr_bits is greater than 24
        if self.num_addr_bits > 24:
            x = self.get_nv_config()
            x[0] = x[0] & 0xFE
            x[1] = 0xFF
            self.set_nv_config(x)
            self.enter_4_byte_address_mode()
        self.initialized = True
        time.sleep(0.125)
        return id
    
    def reset_system(self):
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
        #if self.dev.get(self.CTRL_TERM, "mode.bit_bang"):
        #    return self.cmd_bit_bang(cmd, num_read_bytes)

        self.dev.set(self.CTRL_TERM, "csb1", 0)

        x = None
        try:
            self.dev.write(self.DATA_TERM, 0, cmd)
            if num_read_bytes > 0:
                x = bytearray(num_read_bytes)
                #time.sleep(0.003)
                self.dev.read(self.DATA_TERM, 0, x)
        finally:
            self.dev.set(self.CTRL_TERM, "csb1", 1)
        return x

        self.dev.set(self.CTRL_TERM, "csb1", 0)

    def cmd_bit_bang(self, cmd, num_read_bytes=0):
        self.dev.set(self.CTRL_TERM, "csb1", 0)
        x = None
        try:
            self.write_bb(cmd)
            if num_read_bytes > 0:
                x = bytearray(num_read_bytes)
                #time.sleep(0.003)
                self.read_bb(x)
        finally:
            self.dev.set(self.CTRL_TERM, "csb1", 1)
        return x

    def write_bb(self, cmd):
        for x in cmd:
            for b in range(8):
                self.dev.set(self.CTRL_TERM, "pins.mosi", (x >> (7-b)) & 0x1)
                self.dev.set(self.CTRL_TERM, "pins.sclk", 1)
                self.dev.set(self.CTRL_TERM, "pins.sclk", 0)
                             
    def read_bb(self, buf):
        for pos in range(len(buf)):
            x = 0
            for b in range(8):
                self.dev.set(self.CTRL_TERM, "pins.sclk", 1)
                x = (x << 1) | self.dev.get(self.CTRL_TERM, "miso_s")
                self.dev.set(self.CTRL_TERM, "pins.sclk", 0)
            buf[pos] = x
        
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

    def get_config(self):
        return self.cmd(*self._READ_CONFIG)

    def set_config(self, val):
        self.write_enable()
        log.info("WRITING CONFIG: %02x" % (val,))
        x = self.cmd(bytearray([chr(self._WRITE_CONFIG),val]), 0)
        self.write_enable(False)
        return x

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
            self.cmd(self._WRITE_ENABLE)
            self.dev.set(self.CTRL_TERM, "pins.wpb", 1)
        else:
            self.cmd(self._WRITE_DISABLE)
            self.dev.set(self.CTRL_TERM, "pins.wpb", 0)
        

    def read(self, addr, num_bytes, quad_mode=True):
        """Read in chunks of 256. Not sure why longer reads are failing, but they are."""
        quad_mode = self.quad_mode_read_ok and quad_mode # make sure quad_mode is OK
        log.info("READ: QUAD_MODE=" + str(quad_mode))
        d = bytearray()
        try:
            if quad_mode:
                self.dev.set(self.CTRL_TERM, "mode.quad", 1)

            if False: # reading entire image is broken
                c = bytearray([
                    self._READ_QUAD if quad_mode else self._READ,
                ])
                if self.num_addr_bits > 24:
                    c.append((addr >> 23) & 0xFF)
                c.append((addr >> 16) & 0xFF)
                c.append((addr >>  8) & 0xFF)
                c.append((addr >>  0) & 0xFF)

                if quad_mode:
                    c.append(0)
                d = self.cmd(c, num_bytes)
            else:
                while num_bytes:
                    c = bytearray([
                        self._READ_QUAD if quad_mode else self._READ,
                        ])
                    if self.num_addr_bits > 24:
                        c.append((addr >> 23) & 0xFF)
                    c.append((addr >> 16) & 0xFF)
                    c.append((addr >>  8) & 0xFF)
                    c.append((addr >>  0) & 0xFF)
                    if quad_mode:
                        c.append(0)
                    r = self.cmd(c, min(num_bytes, 512)) #1024))
                    l = len(r)
                    num_bytes -= l
                    addr += l
                    d += r
                    
        finally:
            self.dev.set(self.CTRL_TERM, "mode.quad", 0)
            
        return d

    def write_page(self, addr, data):
        """Writes 'data' to 'addr'. Max length of data is 256 bytes. Assumes
        flash is already erased and ready to program.
        """
        if(len(data) > 256):
            raise Exception("Can only write pages of 256 bytes at a time")
        log.debug(" WRITE PAGE: 0x%x" % addr)
        self.write_enable()
        c = bytearray([self._WRITE])
        if self.num_addr_bits > 24:
            c.append((addr >> 23) & 0xFF)
        c.append((addr >> 16) & 0xFF)
        c.append((addr >>  8) & 0xFF)
        c.append((addr >>  0) & 0xFF)
        c += bytearray(data)
        self.cmd(c)
        while self.get_status()["write_in_progress"]:
            pass
        self.write_enable(False)

    def write(self, addr, data):
        """Writes 'data' to 'addr'. Assumes flash is already erased and ready
        to program."""
        while len(data) > 0:
            try:
                self.write_page(addr, data[:256])
            except:
                time.sleep(0.5)
                self.write_page(addr, data[:256])
            addr += 256
            data = data[256:]
        
    def bulk_erase(self):
        self.write_enable()
        self.cmd(self._BULK_ERASE)
        time.sleep(0.2)
        t0=time.time()
        spinner = ["-",r'\\'[0], "|", r'/', "-", r'\\'[0], "|", r'/']
        while self.get_status()["write_in_progress"]:
            t1 = int(time.time()-t0)
            m = t1/60
            s = t1 - m * 60
            sys.stdout.write("\rBulk Erasing:   %s    %02d:%02d" % (spinner[0], m,s))
            sys.stdout.flush()
            spinner.append(spinner.pop(0))
            time.sleep(0.1)
        sys.stdout.write("\n")
        self.write_enable(False)

    def subsector_erase(self, addr):
        """Erases a 4KB chuck. Any address in the 4KB chuck will work"""
        log.debug(" SUBSECTOR ERASE: 0x%x" % addr)
        self.write_enable()
#        time.sleep(0.01)
        c = bytearray([       self._SUBSECTOR_ERASE, ])
        if self.num_addr_bits > 24:
            c.append((addr >> 23) & 0xFF)
        c.append((addr >> 16) & 0xFF)
        c.append((addr >>  8) & 0xFF)
        c.append((addr >>  0) & 0xFF)
        self.cmd(c)
#        time.sleep(0.01)
        while self.get_status()["write_in_progress"]:
            pass
        self.write_enable(False)

    def enter_4_byte_address_mode(self):
        self.write_enable()
        self.cmd(self._ENTER_4_BYTE_ADDRESS_MODE)
        self.write_enable(False)

    def write_image(self, image, addr=0, verify_while_writing=False, bulk_erase=True, quad_mode=True, ui_callback=None):
        """
            ui_callback(cur,total,seconds)
                Called from write_image with current progress and total size and elapsed seconds.
                If not specified data goes to stdout.
        """
#        image = image[:4096*1]
        addr0 = addr
        num_subsectors = (len(image)+4095)/4096

        if str(type(image)) == "<type 'numpy.ndarray'>":
            image = image.tobytes()
        if type(image) is str:
            image = bytearray(image)
        
        t0 = time.time()
        
        if ui_callback is None:
            sys.stdout.write(" ")
            def default_callback(c,t,sec):
                m, s = divmod ( sec, 60 )
                N = 50
                n0 = c * N / t
                sys.stdout.write("\r%5d/%5d |" % (c+1,t) + ("=" * n0) + (" " * (N-n0)) + "| %02d:%02d" % (m,s))
                sys.stdout.flush()
            ui_callback=default_callback
   

        try: # the flash seems to need some opporations to get it functioning.
            self.get_id()
        except:
            pass

        #x = self.read(addr, len(image), quad_mode=quad_mode)
        #erase_necessary = not(x == bytearray("\xff" * len(image)))
        erase_necessary= True#False
        log.info("Erase Necessary: " + str(erase_necessary))
        
        if 1:# bulk_erase and erase_necessary:
            log.info("Bulk Erasing Flash")
            time.sleep(0.2)
            self.bulk_erase()
        
        log.info(" WRITING IMAGE TO 0x%x LEN=%dMB" % (addr, len(image)/1e6))
        log.info("  NUM_SUBSECTORS=%d" % num_subsectors)
        for subsector_idx in range(num_subsectors):
            iaddr = subsector_idx * 4096
            def write_subsector(addr):
                if not(bulk_erase) and erase_necessary:
                    self.subsector_erase(addr)
                for page in range(16):
                    p = image[iaddr+(page*256):iaddr+(page+1)*256]
                    #print hex(iaddr+(page*256)), str(p[:8]).encode("hex")
                    if len(p) > 0:
                        self.write(addr, p)
                        if verify_while_writing:
                            r = self.read(addr, len(p), quad_mode=quad_mode)
                            if str(r) != str(p):
                                raise Exception("Read verify failed: page=" + str(page))
                    addr += 256
                return addr
            retry = 0
            while True:
                try:
                    addr = write_subsector(addr)
                    break
                except Exception,e:
                    if str(e).startswith("Read verify failed"):
                        if retry >= 0:
                            log.info(str(subsector_idx) + " " + str(e) + ". Retrying " + str(retry))
                        time.sleep(0.1)
                    else:
                        raise
                    retry += 1
                    if retry > 10:
                        raise
#            addr = write_subsector(addr)
            t1 = int(time.time()-t0)
            ui_callback ( subsector_idx, num_subsectors, t1 )

        try:
            sys.stdout.write("\n")
        except:
            pass # because in ui mode stdout might not be open
        self.verify_image(image, addr0, quad_mode=quad_mode)
            
    def verify_image(self, image, addr=0, quad_mode=True):
        t0 = time.time()
        log.info("VERIFYING IMAGE")
        if True:
            rimg = self.read(addr, len(image), quad_mode=quad_mode)
            t1 = time.time()
            if(rimg == image):
                log.info("Verification Passed")
            else:
                for idx, (x,y) in enumerate(zip(image, rimg)):
                    if x != y:
                        print "Mismatch: 0x%x  0x%02x/0x%02x" % (idx+addr, x, y)
                    #break
                raise Exception("Verification Failed at Location: 0x%x" % idx)
        else:
            mismatch = 0
            N = 50
            pages = len(image)/256
            for page in range(pages):
                addr0 = page * 256 + addr
                iaddr = page * 256
                r0 = self.read(addr0, 256, quad_mode=quad_mode)
    
                if(r0 != image[iaddr:iaddr+256]):
                    log.error("Page mismatch at addr=" + hex(addr0))
                    print "Read:", str(r0).encode("hex")
                    print "Actu:", str(image[iaddr:iaddr+256]).encode("hex")
                    mismatch += 1
    
                if(page % 16 == 0): # update page count printing occasionally 
                    n0 = page * N / pages
                    t1 = int(time.time()-t0)
                    m = t1/60
                    s = t1 - m * 60
                    sys.stdout.write("\r%5d/%5d |" % (page/16,pages/16) + ("." * n0) + (" " * (N-n0)) + "| %02d:%02d" % (m,s))
                    sys.stdout.flush()
                    
            if mismatch:
                raise Exception(str(mismatch), " page mismatch(s) found")
            else:
                log.info("Verification Passed")
