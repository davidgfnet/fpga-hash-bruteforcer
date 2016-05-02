
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

module md5_post_stage(
	input         clk,

	input  [31:0] b_in,       // 32 bit B[i] (input from prev stage)
	input  [31:0] c_in,       // 32 bit C[i] (input from prev stage)
	input  [31:0] d_in,       // 32 bit D[i] (input from prev stage)
	input  [31:0] p_in,       // 32 bit P[i] (input from "current" stage)

	output [31:0] b_out,      // 32 bit B[i] (output to next stage)
	output [31:0] c_out,      // 32 bit B[i] (output to next stage)
	output [31:0] d_out       // 32 bit B[i] (output to next stage)
);

`ifdef VERBOSE
	initial $dumpvars(0, b_out);
	initial $dumpvars(0, c_out);
	initial $dumpvars(0, d_out);
`endif

// Parameters to instance the stage
parameter stage_number = 0;  // This is our "i"
parameter rot_amount = 1;    // Number of positions for the rotator (s[i])

// Calculate f_i
reg [31:0] f_i;
always @(*)
begin
	if (stage_number < 16) begin
		f_i = (b_in & c_in) | ((~b_in) & d_in);
	end else if (stage_number < 32) begin
		f_i = (d_in & b_in) | ((~d_in) & c_in);
	end else if (stage_number < 48) begin
		f_i = b_in ^ c_in ^ d_in;
	end else begin
		f_i = c_in ^ (b_in | (~d_in));
	end
end

// Calculate next B
wire [31:0] f_i_sum;
assign f_i_sum = f_i + p_in;

// Left rotate the signal a certain amount (non zero for sure)
wire [31:0] f_i_rot;
assign f_i_rot = { f_i_sum[31-rot_amount:0], f_i_sum[31:32-rot_amount] };

// Add result into the new value for b
wire [31:0] b_next;
assign b_next = b_in + f_i_rot;

// Just forward data to the right ports
wire [31:0] c_next;
wire [31:0] d_next;
assign c_next = b_in;
assign d_next = c_in;

reg [31:0] b_reg;
reg [31:0] c_reg;
reg [31:0] d_reg;

// Update internal state
// This pipestage contains 32*3b = 96b
always @(posedge clk)
begin
	b_reg <= b_next;
	c_reg <= c_next;
	d_reg <= d_next;
end

// Output
assign b_out = b_reg;
assign c_out = c_reg;
assign d_out = d_reg;

endmodule

