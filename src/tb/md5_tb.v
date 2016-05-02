`timescale 1ns / 1ps

module md5_tb();

reg clk = 0;
reg [5:0] offset_in = 6'b000000;
wire [7:0] msbyte_in;

initial begin
	//$dumpfile("md5tb.vcd");
	$dumpvars(0, clk);
	$dumpvars(0, offset_in);
	$dumpvars(0, msbyte_in);
	$dumpvars(0, hash_c);
	$dumpvars(0, hash_d);

	# 10000 $finish;
end

always #0.5 clk = !clk;
always #1 offset_in = offset_in + 1;

assign msbyte_in =  (offset_in == 1) ? 8'h80 :
					(offset_in == 0) ? 8'h61 :
					(offset_in == 56) ? 8'h08 : 8'h00;

wire [31:0] hash_c;
wire [31:0] hash_d;

md5_pipeline testpipe (
	.clk(clk),
	.offset_in(offset_in), .msbyte_in(msbyte_in),
	.c_out(hash_c), .d_out(hash_d)
);

endmodule

