`timescale 1ns / 1ps

// MD5 cracker instance toplevel entity

module toplevel_tb();

// UART interface
wire rx = 1;
wire tx;
reg clk = 1, reset = 1;

reg tx_req;
wire tx_busy;
reg [7:0] tx_byte;


toplevel_bruteforcer test (
	.clk(clk), .reset(reset),
	.uart_rx(tx),
	.aux_uart_rx(1'b1),
	.switch_config(4'h0)
);

uart test_uart(
	.clk(clk), .reset(reset),
	.rx(rx), .tx(tx),

	.tx_byte(tx_byte), .tx_req(tx_req), .tx_busy(tx_busy)
);

`define TESTB_SIZE   4810
`define TESTB2_SIZE  1028

reg [7:0] uart_data  [0: `TESTB_SIZE-1];
reg [7:0] uart_data2 [0:`TESTB2_SIZE-1];

initial begin
	$readmemh("toplevel.vectors", uart_data);
	$readmemh("toplevel2.vectors", uart_data2);

	$dumpvars(0, tx);
	$dumpvars(0, rx);
	$dumpvars(0, clk);
	$dumpvars(0, reset);

	$dumpvars(0, tx_busy);
	$dumpvars(0, tx_req);
	$dumpvars(0, tx_byte);
	$dumpvars(0, fsm_state);
	$dumpvars(0, fsm_state2);

	# 70000000 $finish;
end

always #20 clk = !clk;
always #200 reset = 0;

reg [15:0] fsm_state  =  0;
reg [15:0] fsm_state2 = ~0;

initial #35000000 fsm_state2 = 0;

always @(posedge clk) begin
	tx_req <= 0;
	if (reset) begin
		fsm_state  <= 0;
		fsm_state2 <= ~0;
	end else begin
		if (fsm_state < `TESTB_SIZE) begin
			if (!tx_busy && !tx_req) begin
				tx_req <= 1;
				tx_byte <= uart_data[fsm_state];
				fsm_state <= fsm_state + 1;
			end else begin
				tx_req <= 0;
			end
		end

		if (fsm_state2 < `TESTB2_SIZE) begin
			if (!tx_busy && !tx_req) begin
				tx_req <= 1;
				tx_byte <= uart_data2[fsm_state2];
				fsm_state2 <= fsm_state2 + 1;
			end else begin
				tx_req <= 0;
			end
		end
	end
end

endmodule

