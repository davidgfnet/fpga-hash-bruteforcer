
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

module hash_checker (
	input wire clk,

	// Setup interface
	input  wire        wr_en,     // Write to RAM
	input  wire        zwr_en,    // Zero to RAM
	input  wire [31:0] in_val,    // Value to write
	input  wire [ 8:0] in_addr,   // 16kbit
	input  wire [ 3:0] filter_id, // 16 bloom filters

	// Port A & B
	input  wire [63:0] A_hash,
	input  wire [63:0] B_hash,

	output reg         A_hit,
	output reg         B_hit
);

// For rotation purposes extend hash
wire [127:0] Ah = { A_hash, A_hash };
wire [127:0] Bh = { B_hash, B_hash };

// Generate the 16 hash indices
wire [13:0] A_indices [0:15];
wire [13:0] B_indices [0:15];
// Need to keep the last 5 LSB for next cycle
reg  [ 4:0] A_indices_d [0:15];
reg  [ 4:0] B_indices_d [0:15];

wire [31:0] A_word [0:15], B_word [0:15];  // 32 bit lookup to the bloom filter
wire [15:0] A_bit, B_bit;   // Result is 16 hit/miss bits
reg  [15:0] A_bit_d, B_bit_d;

function [13:0] xor2lane;
	input [27:0] in;
	xor2lane = {
		in[27] ^ in[26], in[25] ^ in[24],
		in[23] ^ in[22], in[21] ^ in[20],
		in[19] ^ in[18], in[17] ^ in[16],
		in[15] ^ in[14], in[13] ^ in[12],
		in[11] ^ in[10], in[ 9] ^ in[ 8],
		in[ 7] ^ in[ 6], in[ 5] ^ in[ 4],
		in[ 3] ^ in[ 2], in[ 1] ^ in[ 0]
	};
endfunction

function [13:0] xor3lane;
	input [41:0] in;
	xor3lane = {
		in[41] ^ in[40] ^ in[39], in[38] ^ in[37] ^ in[36],
		in[35] ^ in[34] ^ in[33], in[32] ^ in[31] ^ in[30],
		in[29] ^ in[28] ^ in[27], in[26] ^ in[25] ^ in[24],
		in[23] ^ in[22] ^ in[21], in[20] ^ in[19] ^ in[18],
		in[17] ^ in[16] ^ in[15], in[14] ^ in[13] ^ in[12],
		in[11] ^ in[10] ^ in[ 9], in[ 8] ^ in[ 7] ^ in[ 6],
		in[ 5] ^ in[ 4] ^ in[ 3], in[ 2] ^ in[ 1] ^ in[ 0]
	};
endfunction

function [13:0] xor4lane;
	input [55:0] in;
	xor4lane = {
		in[55] ^ in[54] ^ in[53] ^ in[52], in[51] ^ in[50] ^ in[49] ^ in[48],
		in[47] ^ in[46] ^ in[45] ^ in[44], in[43] ^ in[42] ^ in[41] ^ in[40],
		in[39] ^ in[38] ^ in[37] ^ in[36], in[35] ^ in[34] ^ in[33] ^ in[32],
		in[31] ^ in[30] ^ in[29] ^ in[28], in[27] ^ in[26] ^ in[25] ^ in[24],
		in[23] ^ in[22] ^ in[21] ^ in[20], in[19] ^ in[18] ^ in[17] ^ in[16],
		in[15] ^ in[14] ^ in[13] ^ in[12], in[11] ^ in[10] ^ in[ 9] ^ in[ 8],
		in[ 7] ^ in[ 6] ^ in[ 5] ^ in[ 4], in[ 3] ^ in[ 2] ^ in[ 1] ^ in[ 0]
	};
endfunction

// Instantiate 16 RAM modules
generate genvar i;
for (i = 0; i < 16; i = i + 1) begin
	assign A_indices[i] = (i  <  6) ? Ah[127-14*i:114-14*i] :
	                      (i  < 12) ? Ah[117-14*(i-6):104-14*(i-6)] ^ Ah[103-14*(i-6):90-14*(i-6)] :
	                      (i  < 14) ? xor2lane(Ah[127-32*(i-12):100-32*(i-12)]) :
	                      (i == 14) ? xor3lane(Ah[116:75]) :
	                                  xor4lane(Ah[123:68]);

	assign B_indices[i] = (i  <  6) ? Bh[127-14*i:114-14*i] :
	                      (i  < 12) ? Bh[117-14*(i-6):104-14*(i-6)] ^ Bh[103-14*(i-6):90-14*(i-6)] :
	                      (i  < 14) ? xor2lane(Bh[127-32*(i-12):100-32*(i-12)]) :
	                      (i == 14) ? xor3lane(Bh[116:75]) :
	                                  xor4lane(Bh[123:68]);

	always @(posedge clk) begin
		A_indices_d[i] <= A_indices[i][4:0];
		B_indices_d[i] <= B_indices[i][4:0];
	end

	ram_module #(.DATA(32), .ADDR(9)) bloom_ram (
		.a_clk(clk), .a_wr(wr_en && (filter_id == i)),
		.a_addr(wr_en  ? in_addr : A_indices[i][13:5]), .a_din(in_val), .a_dout(A_word[i]),

		.b_clk(clk), .b_wr(zwr_en && (filter_id == i)),
		.b_addr(zwr_en ? in_addr : B_indices[i][13:5]), .b_din(32'b0),  .b_dout(B_word[i])
	);

	assign A_bit[i] = A_word[i][A_indices_d[i]];
	assign B_bit[i] = B_word[i][B_indices_d[i]];
end
endgenerate

always @(posedge clk) begin
	A_bit_d <= A_bit;
	B_bit_d <= B_bit;

	A_hit <= &A_bit_d;
	B_hit <= &B_bit_d;
end

endmodule


