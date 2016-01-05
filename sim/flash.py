import Vtb as tb
from nitro_parts.Micron import N25Q
import logging
logging.basicConfig(level=logging.INFO)
log=logging.getLogger(__name__)
import numpy


tb.init("flash.vcd")

d = {}
execfile("../terminals.py", d)
dev = tb.get_dev()
dev.set_di(d["di"])

flash = N25Q.N25Q(dev)

#dev.set("N25Q_CTRL","clk_divider", 4)
#x = "\xAA\x00\xFF\x55\x99"
#
#dev.write("N25Q_DATA", 0, x)
#
#y = numpy.zeros(6, dtype=numpy.uint8)
#dev.read("N25Q_DATA", 0, y)

print "Status=", flash.get_status()
flash.write_enable()
print "Status=", flash.get_status()
flash.write_enable(False)
print "Status=", flash.get_status()

flash.bulk_erase()
while flash.get_status()["write_in_progress"]:
    pass

print "ID=", [ hex(x) for x in flash.get_id() ]

flash.init_system()

y = bytearray([0x32, 0x45, 0x12, 0x40])
flash.write(4,y)
flash.write(4100,y)

x = flash.read(0, 10)
print "READ: ", [ hex(y) for y in x ]
x = flash.read(4096, 10)
print "READ: ", [ hex(y) for y in x ]

flash.subsector_erase(0)
x = flash.read(0, 10)
print "READ: ", [ hex(y) for y in x ]
x = flash.read(4096, 10)
print "READ: ", [ hex(y) for y in x ]


tb.adv(100)
tb.end()
