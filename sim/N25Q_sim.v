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
   reg [7:0] count, datao;
   reg [2:0] pos;
   
   always @(negedge sclk) begin
      pos <= pos + 1;
      if(pos == 0) begin
	 count <= count + 1;
	 datao <= count;
      end else begin
	 datao <= datao << 1;
      end
      miso <= datao[7];
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
