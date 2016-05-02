
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

module md5_top(
	input         clk,
	input         reset,

	input  [ 5:0] offset_in,  // 6 bit offset to update
	input  [ 7:0] msbyte_in,  // 8 bit byte to overwrite

	// Only output the 64 LSB for the hash, since we assume
	// the number of collisions (false positives) is going to be very
	// low (2^-64 * hashrate) even at large hashrates (~1GH/sec)
	// We save one stage doing so (we could output A for 96b output at same cost)
	output [31:0] c_out,      // 32 bit C
	output [31:0] d_out       // 32 bit D
);

endmodule
