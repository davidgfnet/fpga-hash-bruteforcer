
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

module md5_pre_stage(
	input         clk,

	input  [31:0] d_in,       // 32 bit D[i-1] (input from prev stage)

	input  [ 5:0] offset_in,  // 6 bit offset[i-1], offset to update
	input  [ 7:0] msbyte_in,  // 8 bit msbyte[i-1], byte to overwrite

	output [ 5:0] offset_out, // 6 bit offset[i]
	output [ 7:0] msbyte_out, // 8 bit msbyte[i]

	output [31:0] p_out       // 32 bit P[i] (replaces A[i])
);

// Parameters to instance the stage
parameter message_number = 0;  // This is our "g"
parameter konstant = 0;   // 32 bit constant (derived form some weird cosine filter)

wire [3:0] word_selector;
wire [1:0] byte_selector;
assign word_selector = offset_in[5:2];
assign byte_selector = offset_in[1:0];

// Message update logic
reg [31:0] message;
reg [31:0] message_merge;

`ifdef VERBOSE
	initial $dumpvars(0, message);
	initial $dumpvars(0, p_out);
`endif

always @(*)
begin
	// Decode the offset overwrite a byte if needed
	// "g" ranges from 15 to 0

	if (word_selector == message_number)
	begin
		// MD5 is little endian!
		message_merge = {
			{(byte_selector == 2'b11) ?
				msbyte_in : message[31:24]},
			{(byte_selector == 2'b10) ?
				msbyte_in : message[23:16]},
			{(byte_selector == 2'b01) ?
				msbyte_in : message[15: 8]},
			{(byte_selector == 2'b00) ?
				msbyte_in : message[ 7: 0]}
		};
	end
	else
		message_merge = message;
end

// Some optimizations! This should help to cut logic by 8% (just a wild guess)
// Last 64 bit bits are almost zero (XXX0 0000 0000 0000)
// Also byte 55 is either zero or 0x80
wire [31:0] message_next = (message_number == 15) ? 0 :
                           (message_number == 14) ? { 23'h0, message_merge[8:3], 3'h0 } :
                           (message_number == 13) ? { message_merge[31:7], 7'h0 } :
                            message_merge;

// P[i] update logic
reg  [31:0] p;
wire [31:0] p_next;

// Use CSA32? Can help to save 1 adder (scarce resource it seems).
// assign p_next = (konstant + d_in) + message_next;

wire [31:0] res_sums;
wire [31:0] res_carry;
assign res_sums  = konstant ^ d_in ^ message_next;
assign res_carry = (konstant & d_in) | (konstant & message_next) | (d_in & message_next);
assign p_next = res_sums + { res_carry[30:0], 1'b0 };

// Update internal state
// This pipestage contains 32+32 + 8+6 bits = 78b

reg [ 5:0] offset;
reg [ 7:0] msbyte;

always @(posedge clk)
begin
	message <= message_next;
	p <= p_next;
	offset <= offset_in;
	msbyte <= msbyte_in;
end

// Output
assign offset_out = offset;
assign msbyte_out = msbyte;
assign p_out = p;

endmodule

