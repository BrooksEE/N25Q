`timescale 1ps/1ps
`include "terminals_defs.v"

module tb
  (

`ifdef USER_DATA_WIDTH
   inout [`USER_DATA_WIDTH-1:0] user_data
`endif

   
`ifdef verilator   
 `ifdef USER_DATA_WIDTH
   ,
 `endif
   input clk
`endif   

   );

`ifndef UXN1330_IFCLK_FREQ
`define UXN1330_IFCLK_FREQ 50.4
`endif

`ifndef verilator
   reg   clk;
   initial clk=0;
   localparam ifclk_half = 1000000 / `UXN1330_IFCLK_FREQ / 2;
   always #ifclk_half clk = !clk; // 80.64 mhz
`endif

   wire [31:0] fx3_fd;
   wire [1:0]  fx3_fifo_addr;
   wire   fx3_dma_rdy_b;
   wire        fx3_ifclk, fx3_hics_b, fx3_sloe_b, fx3_slrd_b, fx3_slwr_b;
   wire        fx3_pktend_b, fx3_clkout, fx3_int_b;

   reg 	       resetb;

   reg [3:0]   reset_count;
   initial reset_count = 0;
   initial resetb = 0;
   always @(posedge clk) begin
      if(&reset_count) begin
	 resetb <= 1;
      end else begin
	 reset_count <= reset_count + 1;
      end
   end
   wire [15:0] di_term_addr;
   wire [31:0] di_reg_addr;
   wire [31:0] di_len;
   wire di_read_mode;
   wire di_read_req;
   wire di_read;
   wire di_write_mode;
   wire di_write;
   wire [31:0] di_reg_datai;
   wire di_read_rdy;
   wire [31:0] di_reg_datao;
   wire di_write_rdy;
   wire [15:0] di_transfer_status;
   wire        sda, scl;
   wire        ifclk = fx3_ifclk;
   
   fx3 fx3
     (
      .clk                                 (clk),
      .fx3_ifclk                           (fx3_ifclk),
      .fx3_hics_b                          (fx3_hics_b),
      .fx3_sloe_b                          (fx3_sloe_b),
      .fx3_slrd_b                          (fx3_slrd_b),
      .fx3_slwr_b                          (fx3_slwr_b),
      .fx3_pktend_b                        (fx3_pktend_b),
      .fx3_fifo_addr                       (fx3_fifo_addr),
      .fx3_fd                              (fx3_fd),
      .fx3_dma_rdy_b                       (fx3_dma_rdy_b),
      .SCL                                 (scl),
      .SDA                                 (sda)
      );

   wire [31:0] fx3_fd_out, fx3_fd_in;
   wire 	fx3_fd_oe;
   assign fx3_fd    = (fx3_fd_oe) ? fx3_fd_out : 32'bZZZZ;
   assign fx3_fd_in = fx3_fd;

   Fx3HostInterface Fx3HostInterface
     (
      .ifclk(ifclk),
      .resetb(resetb),

      .di_term_addr (di_term_addr ),
      .di_reg_addr  (di_reg_addr  ),
      .di_len       (di_len       ),
      .di_read_mode (di_read_mode ),
      .di_read_req  (di_read_req  ),
      .di_read      (di_read      ),
      .di_read_rdy  (di_read_rdy  ),
      .di_reg_datao (di_reg_datao ),
      .di_write     (di_write     ),
      .di_write_rdy (di_write_rdy ),
      .di_write_mode(di_write_mode),
      .di_reg_datai (di_reg_datai ),
      .di_transfer_status(di_transfer_status),

      .fx3_hics_b(fx3_hics_b),
      .fx3_dma_rdy_b(fx3_dma_rdy_b),
      .fx3_sloe_b(fx3_sloe_b),
      .fx3_slrd_b(fx3_slrd_b),
      .fx3_slwr_b(fx3_slwr_b), 
      .fx3_pktend_b(fx3_pktend_b),
      .fx3_fifo_addr(fx3_fifo_addr),
      .fx3_fd_out(fx3_fd_out),
      .fx3_fd_in(fx3_fd_in),
      .fx3_fd_oe(fx3_fd_oe)

      );
   
   wire flash_wp,flash_mosi,flash_sclk,flash_csb,flash_holdb,flash_miso;
   N25Q N25Q
     (.ifclk(ifclk),
      .resetb(resetb),
      .di_term_addr (di_term_addr     ),
      .di_reg_addr  (di_reg_addr      ),
      .di_read_mode (di_read_mode     ),
      .di_read_req  (di_read_req      ),
      .di_len       (di_len           ),
      .di_read      (di_read          ),
      .di_write_mode(di_write_mode    ),
      .di_write     (di_write         ),
      .di_reg_datai (di_reg_datai     ),
      .di_read_rdy  (di_read_rdy ),
      .di_reg_datao (di_reg_datao),
      .di_write_rdy (di_write_rdy),
      .di_transfer_status(di_transfer_status),
      .di_N25Q_en(),
      .wp(flash_wp),
      .mosi(flash_mosi),
      .sclk(flash_sclk),
      .csb(flash_csb),
      .holdb(flash_holdb),
      .miso(flash_miso)
      );
   
   N25Q_sim N25Q_sim
  (
   .sclk(flash_sclk),
   .mosi(flash_mosi),
   .csb(flash_csb),
   .miso(flash_miso),
   .wp(flash_wp),
   .holdb(flash_holdb)
   );
   

endmodule
// Local Variables:
// verilog-library-flags:("-y ../rtl")
// End:

