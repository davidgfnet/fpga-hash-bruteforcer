
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`timescale 1ns / 1ps
`include "constants.vh"

// MD5 cracker instance toplevel entity

module toplevel_bruteforcer(
	input   clk,
	input   reset,

	// UART interface (to host)
	input   uart_rx,
	output  uart_tx,

	// Secondary UART (slave)
	input   aux_uart_rx,
	output  aux_uart_tx,

	// Switch config
	input [3:0] switch_config

	// Some leds to ease debugging/supervision?
);

initial begin
	$dumpvars(0, cmd_reg);
	$dumpvars(0, fsm_status);
	$dumpvars(0, uart_rx_ready);
	$dumpvars(0, map_pos_in);
	$dumpvars(0, bpayload);
	$dumpvars(0, cracker_id);
	$dumpvars(0, current_offset);
	$dumpvars(0, char_id_out);

	$dumpvars(0, bloom_word);
	$dumpvars(0, bloom_wr);
	$dumpvars(0, bloom_zwr);
	$dumpvars(0, bloom_id_pos);
	$dumpvars(0, finished);
	$dumpvars(0, recv_finished);
	$dumpvars(0, sent_finished);
	$dumpvars(0, device_reset);
	$dumpvars(0, uart_tx);
	$dumpvars(0, uart_rx_byte);
	$dumpvars(0, uart_tx_byte);
	$dumpvars(0, uart_tx_busy);

	$dumpvars(0, hash_out[0]);
	$dumpvars(0, hash_out[3]);
	$dumpvars(0, hit_pulse[0]);
	$dumpvars(0, hit_pulse[1]);
	$dumpvars(0, hit_pulse[2]);
	$dumpvars(0, hit_pulse[3]);

	$dumpvars(0, offset_in[0]);
	$dumpvars(0, offset_in[3]);
	$dumpvars(0, char_byte_in[0]);
	$dumpvars(0, char_byte_in[1]);
	$dumpvars(0, char_byte_in[2]);
	$dumpvars(0, char_byte_in[3]);

	$dumpvars(0, word_counter);
end

// Config
wire [1:0] slave;
assign slave = { 1'b0, (|switch_config) };

// UART interface
wire       uart_rx_ready;
wire [7:0] uart_rx_byte;
reg        uart_tx_request;
wire       uart_tx_busy;
reg  [7:0] uart_tx_byte;

uart sys_uart(
	.clk(clk), .reset(reset),
	.rx(uart_rx), .tx(uart_tx),

	.tx_byte(uart_tx_byte), .tx_req(uart_tx_request), .tx_busy(uart_tx_busy),
	.rx_ready(uart_rx_ready), .rx_byte(uart_rx_byte)
);

// CMD reception and processing (2 bytes per command)
reg [15:0] cmd_reg;
reg [ 3:0] fsm_status;

reg [31:0] bloom_word;   // Bit to set/reset
reg        bloom_wr;     // Write enable to bloom filter
reg        bloom_zwr;    // Zero write to bloom filter
reg [12:0] bloom_id_pos; // We have 16 filters

reg [ 6:0] current_offset_override;
reg [ 7:0] char_byte_out_override;

// Some stuff for the init FSM to work
reg [6:0] map_pos_in;
reg [7:0] map_val_in;
reg       map_wr_in;

reg device_reset;
reg device_reset_cgen;
reg [`NUM_CRACKERS-1:0] device_reset_pipes;
reg device_reset_global;
reg device_reset_uart;
reg device_reset_aux;

wire [ 3:0] cmd_num        = cmd_reg[15:12];
wire [ 1:0] cracker_device = cmd_reg[11:10];
wire [ 1:0] cracker_id     = cmd_reg[ 9: 8];
wire [ 7:0] bpayload       = cmd_reg[ 7: 0];

always @(posedge clk) begin
	map_wr_in <= 0;
	bloom_wr <= 0;
	bloom_zwr <= 0;
	current_offset_override <= { 1'b0, current_offset_override[5:0] };

	// Reset signals are faned out manually, since they are quite timing critical
	// and latency doesn't matter that much
	device_reset_cgen <= device_reset;
	device_reset_pipes <= {{`NUM_CRACKERS{device_reset}}};
	device_reset_global <= device_reset;
	device_reset_aux <= device_reset;
	device_reset_uart <= device_reset;

	if (reset) begin
		fsm_status <= 0;
		device_reset <= 1;
	end else begin
		case (fsm_status)
		0: begin 
			if (uart_rx_ready) begin
				cmd_reg <= { 8'h00, uart_rx_byte };
				fsm_status <= 1;
			end
		end
		1: begin
			if (uart_rx_ready) begin
				cmd_reg <= { uart_rx_byte, cmd_reg[7:0] };
				fsm_status <= 2;
			end
		end
		default: begin
			// Read CMD and actuate accordingly
			case (cmd_num)
				`CMD_RESET: begin
					// Put devices on reset (clear & do nothing!)
					if (cracker_device == slave) begin
						device_reset <= 1;
						bloom_id_pos <= 0;
					end
					fsm_status <= 0;
				end
				`CMD_START: begin
					$display("Start bruteforcing");
					if (cracker_device == slave)
						device_reset <= 0;
					fsm_status <= 0;
				end
				`CMD_PUSH_BLOOM, `CMD_PUSHWR_BLOOM: begin
					if (fsm_status[3] == 0) begin
						// Push data to reg and write
						bloom_word <= { bloom_word[23:0], bpayload };
						if (cmd_num == `CMD_PUSHWR_BLOOM) begin
							fsm_status <= 4'h8;
							bloom_wr <= 1'b1;
						end else
							fsm_status <= 0;
					end
					else begin
						// Advance pointers
						bloom_id_pos <= bloom_id_pos + 1'b1;
						fsm_status <= 0;
					end
				end
				`CMD_ZWR_BLOOM: begin
					if (fsm_status[3] == 0) begin
						fsm_status <= { 1'h1, bpayload[2:0] };
						bloom_zwr <= 1'b1;
					end else begin
						// Advance pointers
						if (fsm_status[2:0] == 0)
							fsm_status <= 0;
						else begin
							fsm_status <= { 1'b1, fsm_status[2:0] - 1'b1 };
							bloom_zwr <= 1'b1;
						end
						bloom_id_pos <= bloom_id_pos + 1'b1;
					end
				end
				`CMD_SET_MSG_BYTE: begin
					// This effectively writes!
					if (cracker_device == slave) begin
						char_byte_out_override <= bpayload;
						current_offset_override <= { 1'b1, current_offset_override[5:0] };
					end
					fsm_status <= 0;
				end
				`CMD_SEL_MSG_BYTE: begin
					// Do nothing for now
					if (cracker_device == slave)
						current_offset_override <= { 1'b0, bpayload[5:0] };
					fsm_status <= 0;
				end
				`CMD_SET_OFFSET: begin
					start_offset[0] <= bpayload;
					fsm_status <= 0;
				end
				`CMD_SET_MAX_CHAR: begin
					max_characters[0] <= bpayload;
					fsm_status <= 0;
				end
				`CMD_PUSH_VPIPE_B: begin
					if (cracker_device == slave)
						vpipe_config[0] <= { bpayload, vpipe_config[0][63:8] };
					fsm_status <= 0;
				end
				`CMD_PUSH_VPIPE_OF: begin
					if (cracker_device == slave)
						vpipe_off_cfg[0] <= { bpayload[5:0], vpipe_off_cfg[0][23:6] };
					fsm_status <= 0;
				end
				`CMD_SET_CS_SIZE: begin
					charset_size[0] <= bpayload[6:0];
					fsm_status <= 0;
				end

				`CMD_SEL_BYTE_MAP: begin
					map_pos_in <= bpayload;
					fsm_status <= 0;
				end
				`CMD_SET_BYTE_MAP: begin
					map_val_in <= bpayload;
					map_wr_in <= 1;
					fsm_status <= 0;
				end
			endcase
		end
		endcase
	end
end

// CHARGEN + CHAR MAP
// Chargen will generate charid + offset, then charmap will
// output the character byte itself.
// At the very end we get a char+offset for every MD5 pipe

reg  [ 5:0] start_offset   [0:1];     // CFG bits
reg  [ 3:0] max_characters [0:1];
reg  [ 6:0] charset_size   [0:1];
reg  [63:0] vpipe_config   [0:1];     // 8 bit char * 4 pipes * 2 vpipes/pipe
reg  [23:0] vpipe_off_cfg  [0:1];     // 6 bit offset * 4 pipes

wire [ 6:0] char_id_out;      // Current char number (not the char itself)
wire [ 5:0] current_offset;   // Current char offset to update
wire [ 7:0] char_byte_out;    // Current char (byte)
wire        finished;         // Finish signal for the pipe
wire [48:0] word_counter;     // Current word being generated
wire [ 1:0] vpipe_override;

reg [48:0] word_counter_copy;
always @(posedge clk)
	word_counter_copy <= word_counter;

char_gen cgen (
	.clk(clk), .reset(reset | device_reset_cgen),
	.start_offset(start_offset[1]),
	.max_characters(max_characters[1]),
	.charset_size(charset_size[1]),
	.word_counter(word_counter), .offset_out(current_offset),
	.msbyte_out(char_id_out), .ooverride(vpipe_override),
	.finished(finished)
);

char_map cmap (
	.clk(clk),
	.char_pos_rd(char_id_out),
	.wr_enable(map_wr_in), .char_pos_wr(map_pos_in), .char_val_wr(map_val_in),
	.msbyte_out(char_byte_out)
);

reg [ 7:0] global_char_byte_out;
reg [ 5:0] global_offset_out;
always @(posedge clk) begin
	global_offset_out <= current_offset;
	global_char_byte_out <= char_byte_out;

	start_offset   [1] <= start_offset   [0];
	max_characters [1] <= max_characters [0];
	charset_size   [1] <= charset_size   [0];
	vpipe_config   [1] <= vpipe_config   [0];
	vpipe_off_cfg  [1] <= vpipe_off_cfg  [0];
end

generate genvar h;
for (h = 0; h < `NUM_CRACKERS; h = h + 1) begin : H1
	// Vpipe override!
	wire [15:0] offset_chunk         = vpipe_config[1][15+16*h:16*h];
	wire [ 7:0] offset_override_byte = vpipe_override[0] ? offset_chunk[15:8] : offset_chunk[7:0];
	wire [ 7:0] vpipe_char_out       = vpipe_override[1] ? offset_override_byte : global_char_byte_out;
	wire [ 5:0] vpipe_offset_out     = vpipe_override[1] ? vpipe_off_cfg[1][5+6*h:6*h] : global_offset_out;

	always @(posedge clk) begin
		offset_in[h]    <= (current_offset_override[6] && cracker_id == h) ? current_offset_override[5:0] : vpipe_offset_out;
		char_byte_in[h] <= (current_offset_override[6] && cracker_id == h) ? char_byte_out_override : vpipe_char_out;
	end
end
endgenerate


// Hashing and checking pipes
// Every pipe reads a char+offset and calculates the hash
// The output gets into the checker (shared for every two pipes)
// Checker outputs a couple of hit bits. In case of hit
// there is a local FIFO for every MD5 pipe to write the current counter
// value in it
// Hasher pipes
reg  [ 7:0] char_byte_in     [0:`NUM_CRACKERS-1]; // Current char to update (the byte!)
reg  [ 5:0] offset_in        [0:`NUM_CRACKERS-1]; // Current offset to update
wire [63:0] hash_out         [0:`NUM_CRACKERS-1]; // Current hash for this pipe (lowest 64b)

// Checker pipes
reg  [63:0] check_hash [0:`NUM_CRACKERS-1]; // Hash to check (checker input)
reg  [48:0] check_word [0:`NUM_CRACKERS-1]; // Word to insert in the pipe (on hit)
wire        hit_pulse  [0:`NUM_CRACKERS-1];

// Result FIFO signals
wire [47:0] fifo_read  [0:`NUM_CRACKERS-1];
wire        fifo_empty [0:`NUM_CRACKERS-1];
reg         fifo_wr    [0:`NUM_CRACKERS-1];
reg         wc_ready   [0:`NUM_CRACKERS-1];
wire [0:`NUM_CRACKERS-1] fifo_ack;

generate genvar w;
for (w = 0; w < `NUM_CRACKERS; w = w + 1) begin : W1
	always @(posedge clk) begin
		check_hash[w] <= hash_out[w];
		fifo_wr[w] <= hit_pulse[w] & wc_ready[w];
		wc_ready[w] <= (&word_counter[47:0]) | (~word_counter[48]);
		check_word[w] <= word_counter[47:0];
	end
end
endgenerate

generate genvar i,j ;
for (i = 0; i < `NUM_CRACKERS; i = i + 2) begin : G1
	for (j = 0; j < 2; j = j + 1) begin : G2
		md5_pipeline md5_core (
			.clk(clk),
			.offset_in(offset_in[i+j]),
			.msbyte_in(char_byte_in[i+j]),
			.c_out(hash_out[i+j][63:32]), .d_out(hash_out[i+j][31: 0])
		);

		// To avoid hit=1 use word_counter's MSB
		fifo #(.width(48)) cracker_out_fifo (
			.clk(clk), .reset(reset | device_reset_pipes[i+j]),
			.wr_port(check_word[i+j][47:0]), .wr_req(fifo_wr[i+j]), //.q_full(0),
			.rd_port(fifo_read[i+j]), .q_empty(fifo_empty[i+j]), .rd_done(fifo_ack[i+j])
		);
		assign fifo_ack[i+j] = (fifo_priority == i+j) && !fifo_empty[fifo_priority] && !global_fifo_full;
	end
	// Checker handles two pipes simultaneously
	// All checkers hold the same data! (We don't have >2 ports RAMs)
	hash_checker checker0 (
		.clk(clk),
		.wr_en(bloom_wr), .zwr_en(bloom_zwr),
		.in_val(bloom_word), .in_addr(bloom_id_pos[8:0]),
		.filter_id(bloom_id_pos[12:9]),
		.A_hash(check_hash[i]), .B_hash(check_hash[i+1]),
		.A_hit(hit_pulse[i]), .B_hit(hit_pulse[i+1])
	);
end
endgenerate

// UART FIFO
// Read stuff from internal fifos into this one
reg  [`LOG2_NUM_CRACKERS-1:0] fifo_priority;
wire [3:0] fifo_priority_ext;
wire global_fifo_full;
wire global_fifo_empty;
reg  global_fifo_done;
wire [47+4:0] global_fifo_rd_port;

assign fifo_priority_ext = { slave, fifo_priority };
always @(posedge clk) begin
	if (reset)
		fifo_priority <= 0;
	else
		fifo_priority <= fifo_priority + 1'b1;
end

fifo #(.width(48+4)) global_response_fifo (
	.clk(clk), .reset(reset | device_reset_global),
	.wr_port({ fifo_priority_ext, fifo_read[fifo_priority] }),
	.wr_req((|fifo_ack)),
	.q_full(global_fifo_full),
	.rd_port(global_fifo_rd_port), .q_empty(global_fifo_empty), .rd_done(global_fifo_done)
);

reg [27:0] ping_cnt;
always @(posedge clk)
	ping_cnt <= ping_cnt + 1'b1;

// Reply logic. For each non-empty FIFO, pop the queue and send
// the 56 bit message back through the UART
reg recv_finished;
reg sent_finished;
reg [ 6:0] finish_delay;
reg [ 3:0] uart_tx_fsm;
reg [55:0] tx_cmd;
always @(posedge clk) begin
	global_fifo_done <= 0;
	uart_tx_request <= 0;

	recv_finished <= finished && (finish_delay == 0);

	// Finish signal delayed 128 cycles to allow pipe drain
	if (finished && (finish_delay != 0))
		finish_delay <= finish_delay - 1'b1;

	if (reset | device_reset_uart) begin
		finish_delay <= ~0;
		sent_finished <= 0;
	end

	if (reset) begin
		uart_tx_fsm <= 0;
	end else begin
		case (uart_tx_fsm)
		0: begin
			if (!device_reset_uart) begin
				if (!global_fifo_empty) begin
					tx_cmd <= { `RESP_HIT, global_fifo_rd_port[51:48], global_fifo_rd_port[47:0] };
					$display("Hit %d %h", global_fifo_rd_port[51:48], global_fifo_rd_port[47:0]);
					uart_tx_fsm <= 7;
					global_fifo_done <= 1;
				end else if (!sec_fifo_empty) begin
					tx_cmd <= sec_fifo_rd_port;
					uart_tx_fsm <= 7;
					sec_fifo_ack <= 1;
				end else if (recv_finished && !sent_finished) begin
					sent_finished <= 1;
					tx_cmd <= { `RESP_FINISHED, slave, 2'h0, 48'h0 };
					$display("Finished");
					uart_tx_fsm <= 7;
				end else if (ping_cnt == 0) begin
					tx_cmd <= { `RESP_PING, slave, 2'h0, word_counter_copy[47:0] };
					led <= ~led;
					$display("Ping");
					uart_tx_fsm <= 7;
				end
			end
		end
		default: begin
			if (!uart_tx_busy && !uart_tx_request) begin
				uart_tx_request <= 1;
				uart_tx_byte <= tx_cmd[7:0];
				tx_cmd <= tx_cmd >> 8;
				uart_tx_fsm <= uart_tx_fsm - 1'b1;
			end
		end
		endcase
	end
end

// Secondary chain UART
// Only used for reception, TX pin is just forwarded

// UART interface
wire       aux_uart_rx_ready;
wire [7:0] aux_uart_rx_byte;

reg  [55:0] aux_uart_tx_byte;
reg  [ 4:0] aux_fsm_counter;

wire sec_fifo_empty;
wire [55:0] sec_fifo_rd_port;
reg sec_fifo_ack;

uart aux_uart(
	.clk(clk), .reset(reset),
	.rx(aux_uart_rx),

	.tx_req(1'b0),
	.rx_ready(aux_uart_rx_ready), .rx_byte(aux_uart_rx_byte)
);

fifo #(.width(48+8)) aux_uart_fifo (
	.clk(clk), .reset(reset | device_reset_aux),
	.wr_port(aux_uart_tx_byte),
	.wr_req(aux_fsm_counter == 0),
	.rd_port(sec_fifo_rd_port), .q_empty(sec_fifo_empty), .rd_done(sec_fifo_ack)
);

// Read bytes from AUX UART in a 56 bit buffer
// After that they will be forwarded to the main UART

always @(posedge clk) begin
	if (aux_fsm_counter == 0 || reset)
		aux_fsm_counter <= 7;

	if (!device_reset_aux) begin
		if (aux_uart_rx_ready) begin
			aux_uart_tx_byte <= { aux_uart_rx_byte, aux_uart_tx_byte[55:8] };
			aux_fsm_counter <= aux_fsm_counter - 1'b1;
		end
	end
end

// Just forward the message, we have a cracker_device field to
// send targeted messages
assign aux_uart_tx = uart_rx;

endmodule

