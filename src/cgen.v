
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

module char_gen(
	input         clk,
	input         reset,

	// Setup inputs, only used at reset
	input  [ 5:0] start_offset,         // Where the bruteforce happens
	input  [ 3:0] max_characters,       // Max number of characters to bruteforce (minus 1)
	input  [ 6:0] charset_size,         // Number of characters (minimum should be 2, 4 to be safe)

	// Running outputs
	output reg [ 48:0] word_counter,  // 49 bit counter to identify the current message
	output reg [  5:0] offset_out,    // 6 bit char updated position
	output reg [  6:0] msbyte_out,    // 7 bit update char value
	output reg [  1:0] ooverride,
	output reg         finished
);

initial $dumpvars(0, fsm_status);
initial $dumpvars(0, current_ptr);
initial $dumpvars(0, updw_counters);
initial $dumpvars(0, ovfw_mask);
initial $dumpvars(0, offset_out);
initial $dumpvars(0, msbyte_out);
initial $dumpvars(0, ooverride);

reg [5:0] start_offset_reg;
reg [6:0] word_status [0:15];
reg [1:0] fsm_status;
reg [3:0] current_ptr;
reg [3:0] current_ptr_d;
reg       ptr_ovfw;

reg [15:0] updw_counters;
reg [15:0] ovfw_mask;

integer g;

// Increment/decrement current char
wire [6:0] updated_value = word_status[current_ptr] + (updw_counters[current_ptr] ? 7'h7F : 7'h01);


// Find longest set sequence, mark finished too
wire [3:0] next_ptr = (ovfw_mask[15:0] == ~16'b0) ? 4'hF :
                      (ovfw_mask[14:0] == ~15'b0) ? 4'hF :
                      (ovfw_mask[13:0] == ~14'b0) ? 4'hE :
                      (ovfw_mask[12:0] == ~13'b0) ? 4'hD :
                      (ovfw_mask[11:0] == ~12'b0) ? 4'hC :
                      (ovfw_mask[10:0] == ~11'b0) ? 4'hB :
                      (ovfw_mask[ 9:0] == ~10'b0) ? 4'hA :
                      (ovfw_mask[ 8:0] == ~ 9'b0) ? 4'h9 :
                      (ovfw_mask[ 7:0] == ~ 8'b0) ? 4'h8 :
                      (ovfw_mask[ 6:0] == ~ 7'b0) ? 4'h7 :
                      (ovfw_mask[ 5:0] == ~ 6'b0) ? 4'h6 :
                      (ovfw_mask[ 4:0] == ~ 5'b0) ? 4'h5 :
                      (ovfw_mask[ 3:0] == ~ 4'b0) ? 4'h4 :
                      (ovfw_mask[ 2:0] == ~ 3'b0) ? 4'h3 :
                      (ovfw_mask[ 1:0] == ~ 2'b0) ? 4'h2 :
                      (ovfw_mask[   0] == ~ 1'b0) ? 4'h1 : 4'h0;

// General counting happens here
always @(posedge clk) begin
	start_offset_reg <= start_offset;

	if (reset | finished) begin
		fsm_status <= 0;
		current_ptr <= 0;
		word_counter <= -72;
		offset_out <= 0;
		msbyte_out <= 0;
		updw_counters <= 0;
		ovfw_mask <= 0;
		for (g = 0; g < 16; g = g + 1) begin
			word_status[g] <= 0;
		end
		if (reset)
			finished <= 0;
		ooverride <= 2'b0x;
	end else begin
		word_counter <= word_counter + 1'b1;

		case (fsm_status[0])
		0: begin
			word_status[current_ptr] <= updated_value;

			// Keep a copy of current_ptr_d
			current_ptr_d <= current_ptr;

			// Check overflow/underflow
			if ( (word_status[current_ptr] == 1              &&  updw_counters[current_ptr]) ||
			     (word_status[current_ptr] == charset_size-2 && !updw_counters[current_ptr]) ) begin

				updw_counters <= updw_counters ^ (16'h1 << current_ptr);
				ovfw_mask     <= ovfw_mask     | (16'h1 << current_ptr);
			end
		end
		1: begin
			// Clear bits
			finished <= (ovfw_mask == 16'hFFFF) | (current_ptr == max_characters);
			ovfw_mask <= ovfw_mask & ( (next_ptr == 4'hF) ? 16'h8000 :
			                           (next_ptr == 4'hE) ? 16'hC000 :
			                           (next_ptr == 4'hD) ? 16'hE000 :
			                           (next_ptr == 4'hC) ? 16'hF000 :
			                           (next_ptr == 4'hB) ? 16'hF800 :
			                           (next_ptr == 4'hA) ? 16'hFC00 :
			                           (next_ptr == 4'h9) ? 16'hFE00 :
			                           (next_ptr == 4'h8) ? 16'hFF00 :
			                           (next_ptr == 4'h7) ? 16'hFF80 :
			                           (next_ptr == 4'h6) ? 16'hFFC0 :
			                           (next_ptr == 4'h5) ? 16'hFFE0 :
			                           (next_ptr == 4'h4) ? 16'hFFF0 :
			                           (next_ptr == 4'h3) ? 16'hFFF8 :
			                           (next_ptr == 4'h2) ? 16'hFFFC :
			                           (next_ptr == 4'h1) ? 16'hFFFE : 16'hFFFF );

			current_ptr <= next_ptr;

			// Output
			offset_out <= current_ptr + start_offset_reg;
			msbyte_out <= word_status[current_ptr];
		end
		endcase

		// Override output
		ooverride <= {
			~(fsm_status[0]),   // Override bit
			fsm_status == 2'h0 ? 1'h0 :
			fsm_status == 2'h2 ? 1'h1 : 1'hX
		};

		fsm_status <= fsm_status + 1;
	end
end

endmodule

