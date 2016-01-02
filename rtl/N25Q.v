module N25Q
  (
   input 	     ifclk,
   input 	     resetb,
   
   input [15:0]      di_term_addr,
   input [31:0]      di_reg_addr,
   input 	     di_read_mode,
   input 	     di_read_req,
   input 	     di_read,
   input 	     di_write_mode,
   input 	     di_write,

   input [31:0]      di_reg_datai,
   output reg 	     di_read_rdy,
   output reg [31:0] di_reg_datao,
   output reg 	     di_write_rdy,
   output reg [15:0] di_transfer_status,
   output reg 	     di_N25Q_en,
   
   output   wp, //When in QIO-SPI mode or in extended SPI mode using
		//QUAD FAST READ commands, the signal functions as
		//DQ2, providing input/output. All data input drivers
		//are always enabled except when used as an
		//output. Micron recommends customers drive the data
		//signals normally (to avoid unnecessary switching
		//current) and float the signals before the memory
		//device drives data on them.
   output mosi, //Transfers data serially into the device. It receives
		//command codes, addresses, and the data to be
		//programmed. Values are latched on the rising edge of
		//the clock. DQ0 is used for input /output during the
		//following operations: DUAL OUTPUT FAST READ, QUAD
		//OUTPUT FAST READ, DUAL INPUT/OUTPUT FAST READ, and
		//QUAD INPUT/OUTPUT FAST READ. When used for output ,
		//data is shifted out on the falling edge of the
		//clock. In DIO-SPI, DQ0 always acts as an
		//input/output. In QIO-SPI, DQ0 always acts as an
		//input/output, with the exception of the PROGRAM or
		//ERASE cycle performed with V PP . The device
		//temporarily enters the extended SPI protocol and
		//then returns to QIO-SPI as soon as V PP goes LOW.
   output sclk, //Provides the timing of the serial
		//interface. Commands, addresses, or data present at
		//serial data inputs are latched on the rising edge of
		//the clock. Data is shifted out on the falling edge
		//of the clock.
   output csb, // When S# is HIGH, the device is deselected and DQ1 (miso)
		// is at High-Z. When in extended SPI mode, with the
		// device deselected, DQ1 is tri-stated. Unless an
		// internal PROGRAM, ERASE, or WRITE STATUS REGISTER
		// cycle is in progress, the device enters standby
		// power mode (not deep power-down mode). Driving S#
		// LOW enables the device, placing it in the active
		// power mode. After power-up, a falling edge on S# is
		// required prior to the start of any command.
   output holdb,// When in quad SPI mode or in extended SPI mode using
		// quad FAST READ commands, the signal functions as
		// DQ3, providing input/output. HOLD# is disabled and
		// RESET# is disabled if the device is selected.
   input  miso  // Transfers data serially out of the device. Data is
		// shifted out on the falling edge of the clock. DQ1
		// is used for input/output during the following
		// operations: DUAL INPUT FAST PROGRAM, QUAD INPUT
		// FAST PROGRAM, DUAL INPUT EXTENDED FAST PROGRAM, and
		// QUAD INPUT EXTENDED FAST PROGRAM. When used for
		// input, data is latched on the rising edge of the
		// clock. In DIO-SPI, DQ1 always acts as an
		// input/output. In QIO-SPI, DQ1 always acts as an
		// input/output, with the exception of the PROGRAM or
		// ERASE cycle performed with the enhanced program
		// supply voltage (V PP ). In this case the device
		// temporarily enters the extended SPI protocol and
		// then returns to QIO-SPI as soon as V PP goes LOW.
   );

   spi_master 
     #(.DATA_WIDTH(8),
       NUM_PORTS(1),
       CLK_DIVIDER_WIDTH(8),
       SAMPLE_PHASE(0)
       )
   spi_master
     (
      .clk(ifclk),
      .resetb(resetb),
      .CPOL(0), 
      .CPHA(0),
      .clk_divider(clk_divider),
      
      .go(go),
      .datai(datai),
      .datao(datao),
      .busy(busy),
      .done(done),
      
      .dout(mosi),
      .din(miso),
      .csb(csb),
      .sclk(sclk)
      );
   
     
endmodule


   
