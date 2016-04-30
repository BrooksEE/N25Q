import nitro, os
from nitro import DeviceInterface, Terminal, Register, SubReg

di=DeviceInterface(
    name='N25Q', 
    comment='N25Q Flahs memory',
    
    terminal_list=[
        Terminal(
            name='N25Q_CTRL',
            comment='Control terminal to the N25Q serial flash memory.',
            addr=4260,
            regAddrWidth=8,
            regDataWidth=32,
            register_list = [
                Register(name='clk_divider',
                         type='int',
                         mode='write',
                         comment='SCLK rate',
                         width=8,
                         init=4,
                     ),
                Register(name='pins',
                         type='int',
                         mode='write',
                         comment='Pins on N25Q',
                         subregs = [
                             SubReg(name="wpb",     width=1, init=0),
                             SubReg(name='holdb',   width=1, init=1),
                         ],
                     ),
                Register(name='csb1',
                         type='int',
                         mode='write',
                         comment='Use this to set csb low to bridge a write and read command',
                         width=1,
                         init=1,
                     ),
                Register(name='mode',
                         type='int',
                         mode='write',
                         subregs = [
                             SubReg(name='quad', width=1, init=0),
                         ],
                ),
            ]
        ),

        Terminal(
            name='N25Q_DATA',
            addr=4261,
            regAddrWidth=0,
            regDataWidth=8,
            comment="Use this terminal to read/write data to/from the spi flash prom." ),
        ],
    )
