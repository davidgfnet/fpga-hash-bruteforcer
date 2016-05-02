`timescale 1ns / 1ps

// Cairnsmore1 Controller FPGA

module filter(
	input  clk,
	input  inp,
	output outp
);

// Shift data in
reg [6:0] shiftref;
always @(posedge clk)
	shiftref <= {shiftref[5:0], inp};

// Vote count
wire [2:0] votes;
assign votes = shiftref[0] + shiftref[1] + 
               shiftref[2] + shiftref[3] + 
               shiftref[4] + shiftref[5] + 
					shiftref[6];

// Calculate winner	
reg win;
always @(posedge clk)
	win <= votes[2];
	
assign outp = win;

endmodule
