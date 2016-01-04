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

dev.set("N25Q_CTRL","clk_divider", 4)
x = "\xAA\x00\xFF\x55\x99"

dev.write("N25Q_DATA", 0, x)

y = numpy.zeros(6, dtype=numpy.uint8)
dev.read("N25Q_DATA", 0, y)


status = flash.get_status()

tb.adv(100)
tb.end()
