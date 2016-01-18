`include "terminals_defs.v"
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
   output reg	     di_write_rdy,
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
   output reg	     mosi, //Transfers data serially into the device. It receives
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

   reg [31:0] sri;
   wire       N25Q_rdy;
   always @(*) begin
      if(di_term_addr == `TERM_N25Q_CTRL) begin
         di_N25Q_en = 1;
         di_reg_datao = N25Q_CTRLTerminal_reg_datao;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 0;
      end else if(di_term_addr == `TERM_N25Q_DATA) begin
         di_N25Q_en   = 1;
         di_reg_datao = { sri[7:0], sri[15:8], sri[23:16], sri[31:24] };
         di_read_rdy  = N25Q_rdy;
         di_write_rdy = N25Q_rdy;
         di_transfer_status = 0;
      end else begin
         di_N25Q_en   = 0;
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 16'hFFFF; // undefined terminal, return error code
      end
   end

   wire we = di_write    && di_term_addr == `TERM_N25Q_DATA;
   wire re = di_read_req && di_term_addr == `TERM_N25Q_DATA;
   wire busy = (di_write || di_read_req) || !rdy;
   assign N25Q_rdy = !busy;
   
   reg rdy;
   reg [24:0] byte_count;
   wire [24:0] next_byte_count = byte_count + 1;
   reg 	       state;
   parameter IDLE=0, READ_WRITE=1;

   reg [31:0] sro;
   reg [2:0] bitpos;
   always @(posedge ifclk or negedge resetb) begin
      if(!resetb) begin
	 rdy        <= 0;
	 byte_count <= 0;
	 bitpos     <= 0;
	 state      <= 0;
	 sro        <= 0;
      end else begin
	 if((!di_write_mode && !di_read_mode) || di_term_addr != `TERM_N25Q_DATA) begin
	    state      <= IDLE;
	    rdy        <= 1;
	    byte_count <= 0;
	 end else begin
	    if(we) begin
	       sro <= { di_reg_datai[7:0], di_reg_datai[15:8], di_reg_datai[23:16], di_reg_datai[31:24] };
	    end else if(re) begin
	       sro <= 0;
	    end
	    
	    if(we || re) begin
	       state  <= READ_WRITE;
	       rdy    <= 0;
	       bitpos <= 0;
	    end else if(state == READ_WRITE) begin
	       bitpos <= bitpos + 1;
	       if(bitpos == 7) begin
		  byte_count <= next_byte_count;
		  /* verilator lint_off WIDTH */
		  if(next_byte_count >= di_len || next_byte_count[1:0] == 0) begin
		  /* verilator lint_on WIDTH */
		     state <= IDLE;
		     rdy <= 1;
		  end
	       end
	    end
	 end
      end
   end

   reg sclk_en;

   wire clk_en = state == READ_WRITE;
   wire [4:0] sri_pos = 5'd31 - {byte_count[1:0], bitpos};
   reg [4:0]  sri_pos_s;
   reg 	      miso_sp, miso_sn;
   reg 	      sclk_en_s;
   
   always @(posedge ifclk) begin
      sclk_en_s <= clk_en;
      sri_pos_s <= sri_pos;
      miso_sp   <= miso;
      if(sclk_en_s) begin
	 sri[sri_pos_s] <= miso_sn;
      end
   end
   
   reg [4:0] wpos;
   wire [4:0] next_wpos = wpos - 1;
   always @(negedge ifclk) begin
      miso_sn <= miso;
      sclk_en <= clk_en;
      if(!di_write_mode) begin
	 wpos <= 0;
      end else if(clk_en) begin
	 wpos <= next_wpos;
      end
      mosi <= sro[next_wpos];
   end

   
   //assign sclk = sclk_en & ifclk;
   ODDR2 sclko(.Q(sclk), .C0(ifclk), .C1(~ifclk), .CE(sclk_en), .D0(1), .D1(0), .R(0), .S(0));

   assign csb   = csb1;
   assign wp    = pins_wp;
   assign holdb = pins_holdb;
endmodule


   
