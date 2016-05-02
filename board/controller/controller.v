`timescale 1ns / 1ps

// Cairnsmore1 Controller FPGA

module controller_toplevel(
	input   clk,

	// USB interface (FT4232H)
	input  USBC_16,  // TXD
	output USBC_17,  // RXD
	input  USBC_24,  // TXD
	output USBC_25,  // RXD
	
	// USB programming interface (FT4232H)
	input  USBC_0,  // TCK
	input  USBC_1,  // TDI
	output USBC_2,  // TDO
	input  USBC_3,  // TMS
	input  USBC_8,  // TXD
	output USBC_9,  // RXD

	// FPGA interface (FPGA 1 & 3)
	output USB1_5,
	input  USB1_7,
	output USB1_8,
	input  USB1_6,
	output USB2_5,
	input  USB2_7,

	output USB3_5,
	input  USB3_7,
	output USB3_8,
	input  USB3_6,
	output USB4_5,
	input  USB4_7,
	
	// FPGA array JTAG iface
	output JTAG_TCK,
	output JTAG_TDI,
	input  JTAG_TDO,
	output JTAG_TMS,

	// Power enable
	output reg EN_1V2_1,
	output reg EN_1V2_2,
	output reg EN_1V2_3,
	output reg EN_1V2_4,
	output reg ARRAY_3V3_EN,

	// FPGA clk (100Mhz)
	output CLOCKS1_1,
	output CLOCKS1_2,
	output CLOCKS2_1,
	output CLOCKS2_2,
	output CLOCKS3_1,
	output CLOCKS3_2,
	output CLOCKS4_1,
	output CLOCKS4_2,
	
	// FAN control
	input  FAN_SENSE1,
	input  FAN_SENSE2,
	input  FAN_SENSE3,
	input  FAN_SENSE4,
	
	// Other
	output reg LED
);

// JTAG enable bit.
// Will connect JTAG iface AND disable clocks
reg        jtag_enable;

// Connect USB interface to 2 and 4
assign USB1_5  = USBC_16;
assign USB3_5  = USBC_24;
assign USBC_17 = USB1_7;
assign USBC_25 = USB3_7;

// FPGA 1 & 2 connection
assign USB1_8 = USB2_7;
assign USB2_5 = USB1_6;

// FPGA 3 & 4 connection
assign USB3_8 = USB4_7;
assign USB4_5 = USB3_6;

// Clock generation (25Mhz -> 200Mhz)
wire clk200mhz, clk25mhz;
main_dcm_sp pll(clk, clk200mhz, clk25mhz);

// Generate 1 second ticks
reg [31:0] tick_counter;
reg        tick1s, tick025s;
always @(posedge clk25mhz) begin
	tick_counter <= (tick_counter >= 25000000) ? 0 : tick_counter + 1'b1;
	tick1s  <= tick_counter == 25000000;
	tick025s <= (tick_counter == 25000000) | (tick_counter == 12500000) |
	            (tick_counter ==  6250000) | (tick_counter == 18750000);
end
	
// Serial interface (on FTDI channel #1)
// allows us to read/write some registers
`define POWER_ARRAY 3'h0
`define JTAG_MODE   3'h1
`define FAN_SENSE   3'h2
`define RESET_FPGA  3'h3

wire [8:0] rx_byte;
reg  [8:0] tx_byte;
uart #(.clock_freq(25000000)) sys_uart(
	.clk(clk25mhz),
	.reset(1'b0),
	.rx(USBC_8), .tx(USBC_9),
	
	.tx_byte(tx_byte[7:0]), .tx_req(tx_byte[8]),
	.rx_ready(rx_byte[8]), .rx_byte(rx_byte[7:0])
);

reg [ 3:0] power_enable;
reg  [6:0] fan_rps;
reg reset_enable;

always @(posedge clk25mhz) begin
	tx_byte <= 0;
	if (rx_byte[8]) begin
		if (rx_byte[7]) begin
			// Write
			case (rx_byte[6:4])
			`POWER_ARRAY: power_enable <= rx_byte[3:0];
			`JTAG_MODE:   jtag_enable  <= rx_byte[  0];
			`RESET_FPGA:  reset_enable <= rx_byte[  0];
			endcase
		end else begin
			// Read
			case (rx_byte[6:4])
			`POWER_ARRAY: tx_byte <= {1'b1, 4'h0, power_enable };
			`JTAG_MODE:   tx_byte <= {1'b1, 7'h0, jtag_enable };
			`FAN_SENSE:   tx_byte <= {1'b1, 1'b0, fan_rps };
			`RESET_FPGA:  tx_byte <= {1'b1, 7'h0, reset_enable };
			endcase
		end
	end
end

// JTAG interface
assign JTAG_TCK = jtag_enable ? USBC_0 : 1'bz;
assign JTAG_TDI = jtag_enable ? USBC_1 : 1'bz;
assign USBC_2   = JTAG_TDO;
assign JTAG_TMS = jtag_enable ? USBC_3 : 1'bz;

// Fan logic
wire [3:0] fan_sense;
filter f1 (clk200mhz, FAN_SENSE1, fan_sense[0]);
filter f2 (clk200mhz, FAN_SENSE2, fan_sense[1]);
filter f3 (clk200mhz, FAN_SENSE3, fan_sense[2]);
filter f4 (clk200mhz, FAN_SENSE4, fan_sense[3]);

// Detect fans ON
reg  [3:0] fan_sense_prev;
reg        fan_step;
reg  [6:0] fan_count;
reg        fan_ok;
always @(posedge clk25mhz) begin
	if (tick025s & !fan_ok)
		LED <= ~LED;
	else if (fan_ok)
		LED <= 1;
	
	if (tick1s) begin
		// We have calculate an overall FAN speed
		// Aprox. adding all FAN speeds (but not quite)
		// Min 600rpm which is 10 steps per tick
		fan_ok <= fan_count > 10;
		fan_count <= 0;
		fan_rps <= (fan_rps * 7 + fan_count) >> 3;
	end else begin
		fan_count <= fan_count + (fan_step ? 1'b1 : 1'b0);
	end

	// Check whether there was a transition
	fan_step <= |(fan_sense_prev & (~fan_sense));
	fan_sense_prev <= fan_sense;
end

// Power up.
reg [ 3:0] power_enable_current;
always @(posedge clk25mhz) begin
	// Delay power up a bit to avoid big current spikes
	if (tick1s) begin
		if (!fan_ok)
			power_enable_current <= 0;
		else if (power_enable_current[0] != power_enable[0])
			power_enable_current <= { power_enable_current[3:1], power_enable[0] };
		else if (power_enable_current[1] != power_enable[1])
			power_enable_current <= { power_enable_current[3:2], power_enable[1], power_enable_current[0] };
		else if (power_enable_current[2] != power_enable[2])
			power_enable_current <= { power_enable_current[3], power_enable[2], power_enable_current[1:0] };
		else if (power_enable_current[3] != power_enable[3])
			power_enable_current <= { power_enable[3], power_enable_current[2:0] };
	end
	
	ARRAY_3V3_EN <= ~(|power_enable_current);
	EN_1V2_1 <=     ~power_enable_current[0];
	EN_1V2_2 <=     ~power_enable_current[1];
	EN_1V2_3 <=     ~power_enable_current[2];
	EN_1V2_4 <=     ~power_enable_current[3];
end

assign CLOCKS1_1 = jtag_enable ? 0 : clk25mhz;
assign CLOCKS2_1 = jtag_enable ? 0 : clk25mhz;
assign CLOCKS3_1 = jtag_enable ? 0 : clk25mhz;
assign CLOCKS4_1 = jtag_enable ? 0 : clk25mhz;

// 2nd clock pin as reset
assign CLOCKS1_2 = reset_enable;
assign CLOCKS2_2 = reset_enable;
assign CLOCKS3_2 = reset_enable;
assign CLOCKS4_2 = reset_enable;

endmodule
