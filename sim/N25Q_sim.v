module N25Q_sim
  (
   input  sclk,
   inout  mosi,
   input  csb,
   output miso,
   input  wp,
   input  holdb
   );

`ifdef verilator
   reg [2:0] rpos;
   reg [3:0] rstate, next_rstate;
   parameter STATE_RX_CMD = 0, STATE_SEND=1, STATE_RCV=2, STATE_RCV_NV_CONFIG=3, STATE_WRITE=4, STATE_READ=5, STATE_RCV_WRITE=6, STATE_SUBSECTOR_ERASE=7;
   reg [7:0] srin;
   wire [7:0] next_srin = { srin[6:0], mosi };
   reg 	      write_enable;
   reg [4:0]  status_dont_care;
   reg 	      write_enable_latch;
   reg 	      write_in_progress;
   
   wire [7:0] status = { write_enable, status_dont_care, write_enable_latch, write_in_progress };

   reg resetb = 0;
   always @(negedge sclk) begin
      resetb <= 1;
   end

   reg [7:0] sro_buf[0:1<<25];
   reg [7:0] sri_buf[0:256];
   reg [7:0] mem_data[0:1<<25];
   reg [8:0] rcv_count;
   reg [3:0] offset;
   wire [31:0] addr = {sri_buf[3], sri_buf[2], sri_buf[1], next_srin };
   reg [31:0] waddr;

   integer    f;
   initial begin
      f=$fopen("../py/flash.image" ,"rb");
      if(f==0) begin
	 $display("Could not open N25Q_DATA_FILE for read");
      end
      for(j=0; j<1<<25; j=j+1) begin
	 mem_data[j] = 255;
      end
      j=0;
      while(!$feof(f) && j<1<<25) begin
	 mem_data[j] = $fgetc(f);
	 j=j+1;
      end
   end
   wire [7:0] mem_data0 = mem_data[0];
   wire [7:0] mem_data1 = mem_data[1];
   wire [7:0] mem_data2 = mem_data[2];
   wire [7:0] mem_data3 = mem_data[3];
   wire [7:0] mem_data4 = mem_data[4];
   
   
//    _WRITE_STATUS      = 0x01
//    _READ_LOCK         = 0xE8
//    _WRITE_LOCK        = 0xE5
//    _READ_FLAG_STATUS  = (0x70, 1)
//    _CLEAR_FLAG_STATUS = 0x50
   reg 	     four_byte_addr_mode;
   reg 	     bulk_erase_in_progress, event_bulk_erase;
   reg [9:0] bulk_erase_counter;
   integer   j;
   reg [15:0] nv_config;
   
   always @(posedge sclk or posedge csb or negedge resetb) begin
      if(!resetb) begin
	 rpos   <= 0;
	 rstate <= STATE_RX_CMD;
	 srin   <= 0;
	 write_enable <= 1;
	 write_enable_latch <= 0;
	 status_dont_care <= 0;
	 write_in_progress <= 0;
	 offset <= 0;
	 event_bulk_erase <= 0;
	 bulk_erase_in_progress <= 0;
	 bulk_erase_counter <= 0;
	 four_byte_addr_mode <= 0;
	 next_rstate <= 0;
	 nv_config <= 16'hFFFF;
	 rcv_count <= 0;
	 waddr <= 0;
      end else if(csb) begin
	 rpos   <= 0;
	 rstate <= STATE_RX_CMD;
	 srin   <= 0;
	 offset <= 0;
	 next_rstate <= 0;
      end else begin
	 srin <= next_srin;
	 rpos <= rpos + 1;
	 write_in_progress <= bulk_erase_in_progress;
	 if(bulk_erase_counter == 1) begin
	    write_enable_latch <= 0;
	 end
	 
	 if(rstate == STATE_RX_CMD) begin
	    if(rpos == 7) begin
	       $display("N25Q FLASH MEM: RX CMD 0x%02h", next_srin);
	       case(next_srin)
		 8'h02: begin
		    $display("  WRITE_PAGE CMD RECEIVED.");
		    next_rstate <= STATE_WRITE;
		    rcv_count <= (four_byte_addr_mode) ? 4 : 3;
		    rstate <= STATE_RCV;
		 end

		 8'h03: begin
		    $display("  READ CMD RECEIVED.");
		    next_rstate <= STATE_READ;
		    rcv_count <= (four_byte_addr_mode) ? 4 : 3;
		    rstate <= STATE_RCV;
		 end

		 8'h04: begin
		    $display("  WRITE_DISABLE CMD RECEIVED.");
		    write_enable_latch <= 0;
		    rstate <= STATE_SEND;
		 end

		 8'h05: begin
		    $display("  READ STATUS CMD RECEIVED. Status = 0x%02x", status);
		    sro_buf[0] <= status;
		    offset <= 1;
		    rstate <= STATE_SEND;
		 end

		 8'h06: begin
		    $display("  WRITE_ENABLE CMD RECEIVED.");
		    write_enable_latch <= 1;
		    rstate <= STATE_SEND;
		 end

		 8'h20: begin
		    $display("  SUBSECTOR ERASE CMD RECEIVED.");
		    rstate <= STATE_RCV;
		    rcv_count <= (four_byte_addr_mode) ? 4 : 3;
		    next_rstate <= STATE_SUBSECTOR_ERASE;
		 end
		 
		 8'hB1: begin
		    $display("  WRITE_NV_CONFIG CMD RECEIVED.");
		    rstate <= STATE_RCV;
		    rcv_count <= 2;
		    next_rstate <= STATE_RCV_NV_CONFIG;
		 end

		 8'hB5: begin
		    $display("  READ_NV_CONFIG CMD RECEIVED. nv_config=0x%x", nv_config);
		    offset <= 1;
		    sro_buf[0] <= nv_config[7:0];
		    sro_buf[1] <= nv_config[15:8];
		    rstate <= STATE_SEND;
		 end

		 8'hB7: begin
		    $display("  ENTER 4 BYTE ADDRESS MODE CMD RECEIVED");
		    four_byte_addr_mode <= 1;
		    rstate <= STATE_SEND;
		 end

		 8'hC7: begin
		    $display("  BULK ERASE CMD RECEIVED.");
		    if(write_enable_latch == 1 && wp) begin
		       event_bulk_erase <= 1;
		    end else begin
		       $display("  CAN'T BULK ERASE. WRITE NOT ENABLED");
		    end
		    rstate <= STATE_SEND;
		 end

		 8'h9e: begin
		    $display("  READ ID CMD RECEIVED.");
		    offset <= 1;
		    sro_buf[0] <= 8'h20;
		    sro_buf[1] <= 8'hBA;
 		    sro_buf[2] <= 8'h19;
		    for(j=3; j<20; j=j+1) begin
		       sro_buf[j] <= 8'h00;
		    end
		    rstate <= STATE_SEND;
		 end
		 
		 default: begin
		    $display("  UNKNOWN CMD RECEIVED. Returning garbage.");
		    rstate <= STATE_SEND;
		 end
	       endcase
	    end else begin
	       event_bulk_erase <= 0;
	    end

	 end else if(rstate == STATE_RCV) begin // if (rstate == STATE_RX_CMD)
	    if(rpos == 7) begin
	       sri_buf[rcv_count-1] <= next_srin;
	       rcv_count <= rcv_count - 1;
	       if(rcv_count == 1) begin
		  offset <= (four_byte_addr_mode) ? 5 : 4;
		  rstate <= STATE_SEND;
		  if(next_rstate == STATE_RCV_NV_CONFIG) begin
		     nv_config <= { next_srin, sri_buf[1] };
		  end else if(next_rstate == STATE_READ) begin
		     for(j=addr; j<1<<25; j=j+1) begin
			sro_buf[j-addr] = mem_data[j];
		     end
		  end else if(next_rstate == STATE_WRITE) begin
		     waddr <= addr;
		     rstate <= STATE_RCV_WRITE;
		  end else if(next_rstate == STATE_SUBSECTOR_ERASE) begin
		     for(j=0; j<4096; j=j+1) begin
			mem_data[(addr & 32'hFFFFF000) + j] = 8'hff;
		     end
		  end
	       end
	    end
	 end else if(rstate == STATE_RCV_WRITE) begin
	    if(rpos == 7) begin
	       waddr[7:0] <= waddr[7:0] + 1;
	       mem_data[waddr] <= next_srin;
	    end
	 end
	 
	 if(event_bulk_erase) begin
	    bulk_erase_counter <= 10'h3FF;
	    bulk_erase_in_progress <= 1;
	 end else if(bulk_erase_counter > 0) begin
	    bulk_erase_counter <= bulk_erase_counter - 1;
	    if(bulk_erase_counter == 1) begin
	       for(j=0; j<1<<25; j=j+1) begin
		  mem_data[j] = 8'hff;
	       end
	    end 
	 end else begin
	    bulk_erase_in_progress <= 0;
	 end
      end // else: !if(csb)
      
	 
   end


   reg [2:0] spos;
   reg [24:0] saddr;
   /* verilator lint_off WIDTH */
   wire [7:0] sro = sro_buf[saddr-offset];
   /* verilator lint_on WIDTH */
   assign miso = sro[7-spos];
   
   
   always @(negedge sclk or posedge csb or negedge resetb) begin
      if(!resetb) begin
	 spos <= 0;
	 saddr <= 0;
      end else if(csb) begin
	 spos <= 0;
	 saddr <= 0;
      end else begin
	 spos <= spos + 1;
	 if(spos == 7) begin
	    saddr <= saddr + 1;
	 end
      end
   end

`else // !`ifdef verilator
   `include "include/DevParam.h"
   N25Qxxx N25Qxxx
     (
      .S(csb),
      .C_(sclk),
      .HOLD_DQ3(holdb),
      .DQ0(mosi),
      .DQ1(miso),
      .Vcc(3300),
      .Vpp_W_DQ2(wp)
      );
`endif   
endmodule
