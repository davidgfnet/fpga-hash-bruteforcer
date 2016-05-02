`timescale 1ns / 1ps

module chargen_tb();

reg clk = 0;
reg reset = 1;
reg [5:0] offset_in = 6'b000000;
wire [7:0] msbyte_in;

// Setup inputs, only used at reset
reg  [ 5:0] start_offset;         // Where the bruteforce happens
reg  [ 3:0] max_characters;       // Max number of characters to bruteforce
reg  [ 6:0] charset_size;         // Number of characters (minimum should be 2, 4 to be safe)

wire [63:0] word_counter;
wire [ 5:0] offset_out;
wire [ 6:0] msbyte_out;
wire finished;

initial begin
	max_characters = 4'h4;
	charset_size = 7'hA;
	start_offset = 0;

	$dumpvars(0, clk);
	$dumpvars(0, reset);
	$dumpvars(0, offset_out);
	$dumpvars(0, msbyte_out);
	$dumpvars(0, finished);

	# 20000 $finish;
end

always #0.5 clk = !clk;
always #10 reset = 0;


char_gen testgen (
	.clk(clk), .reset(reset),
	.start_offset(start_offset),
	.max_characters(max_characters), .charset_size(charset_size),

	.word_counter(word_counter), .offset_out(offset_out),
	.msbyte_out(msbyte_out), .finished(finished)
);

endmodule

