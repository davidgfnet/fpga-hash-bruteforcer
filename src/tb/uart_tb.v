`timescale 1ns / 1ps

// Two UARTs back to back to test TX and RX

module uart_tb();

reg       clk = 1;
reg       reset = 1;
reg       rx = 1;
wire       tx, tx2;
reg [7:0] tx_byte = 8'h5A;
reg       tx_req = 0;
wire       tx_busy;
wire       rx_ready;
wire [7:0] rx_byte;

initial begin
	$dumpvars(0, rx);
	$dumpvars(0, tx);
	$dumpvars(0, tx_byte);
	$dumpvars(0, rx_byte);
	$dumpvars(0, tx_busy);
	$dumpvars(0, clk);
	$dumpvars(0, reset);
	$dumpvars(0, tx_req);
	$dumpvars(0, rx_ready);

	# 2000000 $finish;
end

always #20 clk = !clk;
always #200 reset = 0;

always #105199 tx_byte = ~((tx_byte+5)>>1);
always #400 tx_req  = 1;
always #800 tx_req  = 0;

uart test_uart(
	.clk(clk), .reset(reset),
	.rx(rx), .tx(tx),

	.tx_byte(tx_byte), .tx_req(tx_req), .tx_busy(tx_busy)
);

uart test_uart_2(
	.clk(clk), .reset(reset),
	.rx(tx), .tx(tx2),

	.tx_req(0),
	.rx_ready(rx_ready), .rx_byte(rx_byte)
);

endmodule

