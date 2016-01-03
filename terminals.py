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
                         init=2,
                     ),
                Register(name='pins',
                         type='int',
                         mode='write',
                         comment='Pins on N25Q',
                         subregs = [
                             SubReg(name="wp", width=1, init=1),
                             SubReg(name='holdb', width=1, init=1),
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
