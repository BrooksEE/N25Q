`include "terminals_defs.v"

module iverilog_tests;
   integer i;
   
   tb tb();

   reg [29:0]                        addr;
   reg [7:0] 			     clk_divider, status, flags;
   reg                               passing;
   reg [7:0] 			     args [0:20];
   reg 				     spot;
   
   integer 			     j;
   reg [7:0] rdata[0:1<<10];
   
   initial begin
      passing = 1;
      spot = 0;
      

`ifdef TRACE      
      $dumpfile ( "iverilog_sim.vcd" );
      $dumpvars ( 3, iverilog_tests );
      $display( "Running Simulation" );
`endif

      while (tb.resetb != 1)
        #10000 $display("Waiting for device to come out of reset");
      
      $display ( "Get the Clock Divider." );
      tb.fx3.getW(`TERM_N25Q_CTRL, `N25Q_CTRL_clk_divider,  `WIDTH_N25Q_CTRL_clk_divider, clk_divider);
      $display("Clock Divider=0x%x", clk_divider);

      read_cmd(8'h05, 0, 1);
      $display("READ_STATUS=0x%x", rdata[0]);

      read_cmd(8'h70, 0, 1);
      $display("READ_FLAGS=0x%x", rdata[0]);

      read_cmd(8'hB5, 0, 2);
      $display("READ_NV_CONFIG=0x%x,0x%x", rdata[0], rdata[1]);

      write_cmd(8'h06, 0); // write enable
      write_cmd(8'hB7, 0); // enter 4 byte addr mode

      write_cmd(8'h06, 0); // write enable
      args[0] = 8'h00; // first four bytes are the address
      args[1] = 8'h00;
      args[2] = 8'h00;
      args[3] = 8'h00;
      args[4] = 8'h01;
      args[5] = 8'h02;
      args[6] = 8'h03;
      args[7] = 8'h04;
      write_cmd(8'h02, 8); // page program

      wait_for_write();

      write_cmd(8'h06, 0); // write enable
      args[0] = 8'h00; // first four bytes are the address
      args[1] = 8'h10;
      args[2] = 8'h00;
      args[3] = 8'h00;
      args[4] = 8'h21;
      args[5] = 8'h22;
      args[6] = 8'h23;
      args[7] = 8'h24;
      args[7] = 8'h25;
      write_cmd(8'h02, 9); // page program
      
      wait_for_write();
      
      read_cmd(8'h03, 5, 4106); // read
      args[0] = 8'h00; // first four bytes are the address
      args[1] = 8'h00;
      args[2] = 8'h00;
      args[3] = 8'h00;
      for(j=0; j<10; j=j+1) begin
	 $display("%d: %x", j, rdata[j]);
      end
      for(j=4096; j<4106; j=j+1) begin
	 $display("%d: %x", j, rdata[j]);
      end
      
      
      
      

      
//      write_cmd(8'h06, 0); // write enable
//      write_cmd(8'hC7, 0); // bulk erase
//      read_cmd(8'h05, 0, 1);
//      while(rdata[0] & 1'b1) begin
//	 read_cmd(8'h05, 0, 1);
//	 $display("READ_STATUS=0x%x", rdata[0]);
//      end
      
//      $display("Waiting for Memory Controller Block (MCB) to calibrate to SDRAM");
//      while(calib_done !== 1) begin
//         get_status();
//         $display("%d: Status = 0x%x, pll_locked=%d calib_done=%d", $time, dram_status, pll_locked, calib_done);
//      end
//
//
//      check_dram_write_read();
//      check_dram_rw_addr();
//      

      
      if(passing)
        $display("PASS: All Tests");
      else
        $display("FAIL: All Tests");
      
      
      $display("DONE");
      $finish;
   end

   task wait_for_write;
      begin
	 read_cmd(8'h05, 0, 1);
	 while(rdata[0] & 1'b1) begin
	    read_cmd(8'h05, 0, 1);
	    $display("READ_STATUS=0x%x", rdata[0]);
	 end
      end
   endtask
   
   task write_cmd;
      input [7:0] cmd;
      input [7:0] num_args;
      begin
	 tb.fx3.setW(`TERM_N25Q_CTRL, `N25Q_CTRL_csb1, 1, 0);
	 tb.fx3.rdwr_data_buf[0] = cmd;
	 for(i=0; i<num_args; i=i+1) begin
	    tb.fx3.rdwr_data_buf[i+1] = args[i];
	 end
	 tb.fx3.write(`TERM_N25Q_DATA, 0, num_args+1);
	 tb.fx3.setW(`TERM_N25Q_CTRL, `N25Q_CTRL_csb1, 1, 1);
      end
   endtask

   
   task read_cmd;
      input [7:0] cmd;
      input [7:0] num_args;
      input [7:0] num_read_bytes;
      begin
	 tb.fx3.setW(`TERM_N25Q_CTRL, `N25Q_CTRL_csb1, 1, 0);
	 tb.fx3.rdwr_data_buf[0] = cmd;
	 for(i=0; i<num_args; i=i+1) begin
	    tb.fx3.rdwr_data_buf[i+1] = args[i];
	 end
	 tb.fx3.write(`TERM_N25Q_DATA, 0, num_args+1);
	 tb.fx3.read(`TERM_N25Q_DATA, 0, num_read_bytes);
	 for(i=0; i<num_read_bytes; i=i+1) begin
	    rdata[i] = tb.fx3.rdwr_data_buf[i];
	 end
	 tb.fx3.setW(`TERM_N25Q_CTRL, `N25Q_CTRL_csb1, 1, 1);
      end
   endtask
      
//   task get_status();
//      begin
//         UXN1330_tb.fx3.getW(`TERM_DRAM_CTRL, `DRAM_CTRL_status, `WIDTH_DRAM_CTRL_status, dram_status);
//         pll_locked = dram_status[`DRAM_CTRL_status_pll_locked];
//         calib_done = dram_status[`DRAM_CTRL_status_calib_done];
//      end
//   endtask // get_status
//
//   task check_dram_write_read();
//      integer results;
//      begin
//
//         $display("Performing dram write/read tests of random data to random locations.");
//         addr = 30'h3FFFFFC & $random;
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            wr_buf[i] = $random;
//            UXN1330_tb.fx3.rdwr_data_buf[i] = wr_buf[i];
//         end
//         
//         $display("Writing %d random bytes to address 0x%x in DRAM", BUF_LEN, addr);
//         UXN1330_tb.fx3.write(`TERM_DRAM, addr, BUF_LEN);
//
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            UXN1330_tb.fx3.rdwr_data_buf[i] = 8'hXX;
//         end
//         
//         $display("Reading %d bytes from address 0x%x in DRAM", BUF_LEN, addr);
//         UXN1330_tb.fx3.read(`TERM_DRAM,  addr, BUF_LEN);
//
//         
//         results = 1;
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            if(wr_buf[i] !== UXN1330_tb.fx3.rdwr_data_buf[i]) begin
//               results = 0;
//               $display(" write/read error at position %d: wrote 0x%x  read:0x%x", i, wr_buf[i], UXN1330_tb.fx3.rdwr_data_buf[i]);
//            end
//         end
//
//	 #100000
//
//         $display("Again Reading %d bytes from address 0x%x in DRAM", BUF_LEN, addr);
//         UXN1330_tb.fx3.read(`TERM_DRAM,  addr, BUF_LEN);
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            if(wr_buf[i] !== UXN1330_tb.fx3.rdwr_data_buf[i]) begin
//               results = 0;
//               $display(" 2nd pass write/read error at position %d: wrote 0x%x  read:0x%x", i, wr_buf[i], UXN1330_tb.fx3.rdwr_data_buf[i]);
//            end
//         end
//
//         if(results) begin
//            $display("PASS: dram write/read test");
//         end else begin
//            $display("FAIL: dram write/read test");
//            passing= 0;
//
//         end
//      end
//   endtask
//
//   task check_dram_rw_addr();
//      integer results;
//      integer offset;
//      
//      begin
//         offset = 24;
//         
//         $display("Performing dram write/read address tests.");
//         addr = 100;
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            wr_buf[i] = 8'hAA;
//            UXN1330_tb.fx3.rdwr_data_buf[i] = wr_buf[i];
//         end
//         
//         $display("Writing %d 8'hAA bytes to address 0x%x in DRAM", BUF_LEN, addr);
//         UXN1330_tb.fx3.write(`TERM_DRAM, addr, BUF_LEN);
//
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            wr_buf[i] = 8'h55;
//            UXN1330_tb.fx3.rdwr_data_buf[i] = wr_buf[i];
//         end
//
//         UXN1330_tb.fx3.write(`TERM_DRAM, addr-offset, offset);
//         
//         for(i=0; i<BUF_LEN; i=i+1) begin
//            UXN1330_tb.fx3.rdwr_data_buf[i] = 8'hXX;
//         end
//         
//         $display("Reading %d bytes from address 0x%x in DRAM", BUF_LEN, addr-offset);
//         UXN1330_tb.fx3.read(`TERM_DRAM,  addr-offset, BUF_LEN+offset);
//         
//         results = 1;
//         for(i=0; i<offset; i=i+1) begin
//            if(UXN1330_tb.fx3.rdwr_data_buf[i] !== 8'h55) begin
//               results = 0;
//               $display(" write/read error at position %d: wrote 0x55  read:0x%x", i, UXN1330_tb.fx3.rdwr_data_buf[i]);
//            end
//         end
//         for(i=offset; i<BUF_LEN+offset; i=i+1) begin
//            if(UXN1330_tb.fx3.rdwr_data_buf[i] !== 8'hAA) begin
//               results = 0;
//               $display(" write/read error at position %d: wrote 0xAA  read:0x%x", i, UXN1330_tb.fx3.rdwr_data_buf[i]);
//            end
//         end
//         if(results) begin
//            $display("PASS: dram write/read addr test");
//         end else begin
//            $display("FAIL: dram write/read addr test");
//            passing= 0;
//
//         end
//      end
//   endtask

endmodule
