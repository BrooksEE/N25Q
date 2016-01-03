module N25Q_sim
  (
   input  sclk,
   input  mosi,
   input  csb,
   output reg miso,
   input  wp,
   input  holdb
   );

   reg [7:0] count, datao;
   reg [2:0] pos;
   
   always @(posedge sclk) begin
      pos <= pos + 1;
      if(pos == 0) begin
	 count <= count + 1;
	 datao <= count;
      end else begin
	 datao <= datao << 1;
      end
      miso <= datao[7];
   end
endmodule
