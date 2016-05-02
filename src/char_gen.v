
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

// Maximum charset size is 128 (7bit)
// Maximum number of max chars is 15

module char_gen(
	input         clk,
	input         reset,

	// Setup inputs, only used at reset
	input  [ 5:0] start_offset,         // Where the bruteforce happens
	input  [ 3:0] max_characters,       // Max number of characters to bruteforce (minus 1)
	input  [ 7:0] charset_size,         // Number of characters (minimum should be 2, 4 to be safe)
	input  [ 6:0] charset_size_p,       // Write addr
	input         charset_size_wr,      // Write enable for above signal

	// Running outputs
	output reg [48:0] word_counter,         // 56 bit counter to identify the current message (enough!)
	output reg [ 5:0] offset_out,           // 6 bit offset to update
	output reg [ 6:0] msbyte_out,           // 8 bit byte to overwrite
	output reg        finished
);

reg [48:0] word_counter_value;
reg signal_finished;

`define MAX_BITS 16

// We keep 16 7b registers with the value and 1 bit for up/down
reg [47:0] pre_counters_value [0:15];  // Pre-scaling counters, must be very big!
reg [47:0] pre_counters_max   [0:15];  // Pre-scaling counters reset value
reg [ 6:0] counters_value     [0:15];  // Value itself for the counters
reg [15:0] counters_updwn;             // Up/Down control for counters
wire counters_flip [0:15];             // Flip signal, whether updwn is flipping
reg [15:0] counters_flipped;           // Whether we flipped on last cycle

reg [15:0] counters_update;            // Whether the counter was updated (only 1 bit set at a time, otherwise its a bug)
reg [ 5:0] reg_start_offset;           // Start offest

generate genvar i;
for (i = 0; i < `MAX_BITS; i = i + 1) begin
	assign counters_flip[i] =
		(counters_value[i] == 6'h01          && counters_updwn[i] == 1) ||
		(counters_value[i] == charset_size-2 && counters_updwn[i] == 0);
end
endgenerate

reg [ 6:0] finish_delay;

integer g;
always @(posedge clk) begin
	reg_start_offset <= start_offset;
	counters_update <= 0;
	if (reset)
		finish_delay <= ~0;

	if (reset | finished) begin
		for (g = 0; g < `MAX_BITS; g = g + 1) begin
			pre_counters_value[g] <= pre_counters_max[g];
			counters_value[g] <= 0;
			counters_updwn[g] <= 0;
		end
		counters_updwn <= 0;
		counters_flipped <= 0;
		word_counter_value <= -72; // 64 cycle pipeline + some delay cycles here and there
		signal_finished <= ~reset;
	end else begin
		signal_finished <= signal_finished | counters_update[max_characters];
		word_counter_value <= word_counter_value + 1'b1;
		for (g = 0; g < `MAX_BITS; g = g + 1) begin
			if (pre_counters_value[g] == 0)
				pre_counters_value[g] <= pre_counters_max[g];
			else
				pre_counters_value[g] <= pre_counters_value[g] - 1'b1;
		end
		for (g = 0; g < `MAX_BITS; g = g + 1) begin
			if (pre_counters_value[g] == 0) begin
				if (!counters_flipped[g]) begin
					counters_value[g] <= counters_updwn[g] ? counters_value[g] - 1'b1 : counters_value[g] + 1'b1;
					counters_update[g] <= 1;
				end

				counters_updwn[g] <= counters_updwn[g] ^ (counters_flip[g]);
				counters_flipped[g] <= counters_flip[g];
			end
		end
	end

	// Finish signal delayed 128 cycles to allow pipe drain
	if (signal_finished && (finish_delay != 0))
		finish_delay <= finish_delay - 1'b1;
end

generate genvar j;
	for (j = 0; j < 6; j = j + 1) begin
	always @(posedge clk) begin
			if (charset_size_wr && charset_size_p[2:0] == j)
				pre_counters_max[charset_size_p[6:3]][j*8+7:j*8] <= charset_size;
		end
	end
endgenerate

wire [3:0] updated_counter;
assign updated_counter = 
	counters_update[ 0] ?  0 :
	counters_update[ 1] ?  1 :
	counters_update[ 2] ?  2 :
	counters_update[ 3] ?  3 :
	counters_update[ 4] ?  4 :
	counters_update[ 5] ?  5 :
	counters_update[ 6] ?  6 :
	counters_update[ 7] ?  7 :
	counters_update[ 8] ?  8 :
	counters_update[ 9] ?  9 :
	counters_update[10] ? 10 :
	counters_update[11] ? 11 :
	counters_update[12] ? 12 :
	counters_update[13] ? 13 :
	counters_update[14] ? 14 :
	counters_update[15] ? 15 : 0;

// Last stage FF
always @(posedge clk) begin
	offset_out <= updated_counter + reg_start_offset;
	msbyte_out <= counters_value[updated_counter];
	word_counter <= word_counter_value;
	finished <= (signal_finished && (finish_delay == 0));
end

endmodule

