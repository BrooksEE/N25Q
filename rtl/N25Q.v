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
   input [31:0]      di_len,

   input [31:0]      di_reg_datai,
   output reg 	     di_read_rdy,
   output reg [31:0] di_reg_datao,
   output reg 	     di_write_rdy,
   output reg [15:0] di_transfer_status,
   output reg 	     di_N25Q_en,
   
   output 	     wp, //When in QIO-SPI mode or in extended SPI mode using
		//QUAD FAST READ commands, the signal functions as
		//DQ2, providing input/output. All data input drivers
		//are always enabled except when used as an
		//output. Micron recommends customers drive the data
		//signals normally (to avoid unnecessary switching
		//current) and float the signals before the memory
		//device drives data on them.
   output 	     mosi, //Transfers data serially into the device. It receives
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
   output 	     sclk, //Provides the timing of the serial
		//interface. Commands, addresses, or data present at
		//serial data inputs are latched on the rising edge of
		//the clock. Data is shifted out on the falling edge
		//of the clock.
   output 	     csb, // When S# is HIGH, the device is deselected and DQ1 (miso)
		// is at High-Z. When in extended SPI mode, with the
		// device deselected, DQ1 is tri-stated. Unless an
		// internal PROGRAM, ERASE, or WRITE STATUS REGISTER
		// cycle is in progress, the device enters standby
		// power mode (not deep power-down mode). Driving S#
		// LOW enables the device, placing it in the active
		// power mode. After power-up, a falling edge on S# is
		// required prior to the start of any command.
   output 	     holdb,// When in quad SPI mode or in extended SPI mode using
		// quad FAST READ commands, the signal functions as
		// DQ3, providing input/output. HOLD# is disabled and
		// RESET# is disabled if the device is selected.
   input 	     miso  // Transfers data serially out of the device. Data is
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


   wire   di_clk = ifclk;
   
`include "N25Q_CTRLTerminalInstance.v"

   reg [1:0] pos;
   reg [31:0] N25Q_DATA_reg_datao;
   wire       N25Q_DATA_rdy = di_term_addr == `TERM_N25Q_DATA && (!di_write) && (!di_read_req) && (!busy) && (!go) && (pos == 0 || bytes_left == 0);
   
   always @(*) begin
      if(di_term_addr == `TERM_N25Q_CTRL) begin
         di_N25Q_en = 1;
         di_reg_datao = N25Q_CTRLTerminal_reg_datao;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 0;
      end else if(di_term_addr == `TERM_N25Q_DATA) begin
         di_N25Q_en = 1;
         di_reg_datao = N25Q_DATA_reg_datao;
         di_read_rdy  = N25Q_DATA_rdy;
         di_write_rdy = N25Q_DATA_rdy;
         di_transfer_status = 0;
      end else begin
         di_N25Q_en = 0;
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 16'hFFFF; // undefined terminal, return error code
      end
   end

   wire busy, done;
   reg [31:0] datai;
   wire [7:0] datao;
   reg 	      go;
   reg [23:0] bytes_left;
   reg 	      mode_s;
   
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 go <= 0;
	 pos <= 0;
	 datai <= 0;
	 N25Q_DATA_reg_datao <= 0;
	 bytes_left <= 0;
	 mode_s <= di_write;
      end else begin
	 mode_s <= di_write_mode || di_read_mode;
	 if(!di_write_mode && !di_read_mode) begin
	    datai <= 0;
	    pos   <= 0;
	    bytes_left <= 0;
	 end else if(di_term_addr == `TERM_N25Q_DATA) begin
	    if((di_write_mode || di_read_mode) && !mode_s) begin
	       bytes_left <= di_len[23:0];
	    end else if(go) begin
	       bytes_left <= bytes_left - 1;
	    end
	    if(di_write_mode) begin
	       if(di_write) begin
		  datai <= di_reg_datai;
		  pos <= pos + 1;
		  go <= 1;
	       end else begin
		  if((bytes_left > 0) && (pos != 0) && !go && !busy) begin
		     datai <= datai >> 8;
		     go <= 1;
		     pos <= pos + 1;
		  end else begin
		    go <= 0;
		  end
	       end
	    end else if(di_read_mode) begin
	       if(di_read_req) begin
		  go <= 1;
		  pos <= pos + 1;
		  N25Q_DATA_reg_datao <= 0;
	       end else begin
		  if(!go && !busy) begin
		     if(pos == 1) begin
			N25Q_DATA_reg_datao[7:0] <= datao;
		     end else if(pos == 2) begin
			N25Q_DATA_reg_datao[15:8] <= datao;
		     end else if(pos == 3) begin
			N25Q_DATA_reg_datao[23:16] <= datao;
		     end else if(pos == 0) begin
			N25Q_DATA_reg_datao[31:24] <= datao;
		     end

		     if((bytes_left > 0) && (pos > 0)) begin
			go <= 1;
			pos <= pos + 1;
		     end else begin
			go <= 0;
		     end
		  end else begin
		     go <= 0;
		  end
	       end
	    end
	 end
      end
   end

   wire csb0;
   spi_master 
     #(.DATA_WIDTH(8),
       .NUM_PORTS(1),
       .CLK_DIVIDER_WIDTH(8),
       .SAMPLE_PHASE(0)
       )
   spi_master
     (
      .clk(ifclk),
      .resetb(resetb),
      .CPOL(mode_cpol), 
      .CPHA(mode_cpha),
      .clk_divider(clk_divider),
      
      .go(go),
      .datai(datai[7:0]),
      .datao(datao),
      .busy(busy),
      .done(done),
      
      .dout(miso),
      .din(mosi),
      .csb(csb0),
      .sclk(sclk)
      );

   assign csb   = csb1 && csb0;
   assign wp    = pins_wp;
   assign holdb = pins_holdb;
endmodule


   
