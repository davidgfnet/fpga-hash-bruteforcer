
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps

module queue #(parameter width = 16)
(
	input         wr_clk,
	input         rd_clk,
	input         reset,

	// Write port
	input  [(width-1):0] wr_port,  // Data in port
	input                wr_req,   // Request to add data into the queue
	output               q_full,   // The queue is full (cannot write any more)

	// Read port
	output [(width-1):0] rd_port,  // Next data in the queue
	output               q_empty,  // The queue is empty! (cannot read!)
	input                rd_done   // The user read the current data within the queue
);

parameter nentries = 4;
parameter entrysz = 2;  // Log(entries) (wrap bit)

initial $dumpvars(0, write_ptr);
initial $dumpvars(0, read_ptr);

// Aux fn
function [entrysz:0] binary2gray;
	input [entrysz:0] value;
	integer i;
	begin
		binary2gray[entrysz] = value[entrysz];
		for (i = entrysz; i > 0; i = i - 1)
			binary2gray[i-1] = value[i] ^ value[i-1];
	end
endfunction
function [entrysz:0] gray2binary;
	input [entrysz:0] value;
	integer i,j;
	begin
		gray2binary[entrysz] = value[entrysz];
		for (i = entrysz-1; i >= 0; i = i - 1)
			gray2binary[i] = value[i] ^ gray2binary[i+1];
	end
endfunction

// The MSB bit of the rd/wr pointer is used for wraping purposes
// So when rd=wr means it's empty and when wr = rd + N (where N is
// queue size) means that it's full.

// Mantain an entry buffer, and write pointer
wire [entrysz:0]    nentries_bus;
reg [entrysz:0]     write_ptr;
reg [(width-1):0]   entries [0:(nentries-1)];

wire [entrysz:0] next_write_ptr;
reg  [entrysz:0] gray_write_ptr;
reg  [entrysz:0] received_read_ptr;
assign nentries_bus = nentries;
assign next_write_ptr = write_ptr + 1;  // Advance write pointer
assign q_full = (received_read_ptr - write_ptr) == nentries_bus;

always @(posedge wr_clk)
begin
	if (reset) begin
		write_ptr <= 0;
	end else begin
		if (wr_req) begin
			write_ptr <= next_write_ptr;
			entries[write_ptr[(entrysz-1):0]] <= wr_port;
		end
		gray_write_ptr <= binary2gray(write_ptr);
		received_read_ptr <= gray2binary(read_ptr_2);
	end
end

// Read logic
reg [entrysz:0]     read_ptr;
assign rd_port = entries[read_ptr[(entrysz-1):0]];

wire [entrysz:0] next_read_ptr;
reg  [entrysz:0] gray_read_ptr;
reg  [entrysz:0] received_write_ptr;
assign next_read_ptr = read_ptr + 1;  // Advance read ptr

always @(posedge rd_clk)
begin
	if (reset) begin
		read_ptr <= 0;
	end else begin
		if (rd_done) begin
			read_ptr <= next_read_ptr;
		end
		gray_read_ptr <= binary2gray(read_ptr);
		received_write_ptr <= gray2binary(write_ptr_2);
	end
end

assign q_empty = (read_ptr == received_write_ptr);

// Delayed lines
reg [entrysz:0] read_ptr_1;
reg [entrysz:0] read_ptr_2;

reg [entrysz:0] write_ptr_1;
reg [entrysz:0] write_ptr_2;

always @(posedge rd_clk) begin
	write_ptr_1 <= gray_write_ptr;
	write_ptr_2 <= write_ptr_1;
end
always @(posedge wr_clk) begin
	read_ptr_1 <= gray_read_ptr;
	read_ptr_2 <= read_ptr_1;
end

endmodule

