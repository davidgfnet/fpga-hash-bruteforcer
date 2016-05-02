`timescale 1ns / 1ps

// Icarus top level

module icarus_toplevel(
	input   input_clk,
	input   reset,

	// UART interface (to host)
	input   uart_rx,
	output  uart_tx,

	// Secondary UART (slave)
	input   aux_uart_rx,
	output  aux_uart_tx,

	// Switch config
	input [2:0] switch_config

	// Some leds to ease debugging/supervision?
);

main_clk pll(input_clk, clk);

toplevel_bruteforcer bruteforcer(
	.clk(clk),
	.reset(reset),
	.uart_rx(uart_rx), .uart_tx(uart_tx),
	.aux_uart_rx(aux_uart_rx), .aux_uart_tx(aux_uart_tx),
	.switch_config(switch_config)
);

endmodule

