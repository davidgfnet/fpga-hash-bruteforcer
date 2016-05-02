`timescale 1ns / 1ps

module queue_tb();

reg wr_clk = 1;
reg rd_clk = 1;
reg reset = 1;

reg  [15:0] wr_port = 16'hdead;
reg  wr_req = 0;
wire  q_full;
wire  q_full2;

wire [15:0] rd_port;
wire [15:0] rd_port2;
wire q_empty;
wire q_empty2;
reg rd_done = 0;

initial begin
	$dumpvars(0, wr_clk);
	$dumpvars(0, rd_clk);
	$dumpvars(0, reset);
	$dumpvars(0, wr_port);
	$dumpvars(0, wr_req);
	$dumpvars(0, q_full);
	$dumpvars(0, q_full2);
	$dumpvars(0, rd_port);
	$dumpvars(0, rd_port2);
	$dumpvars(0, q_empty);
	$dumpvars(0, q_empty2);
	$dumpvars(0, rd_done);

	# 1000000 $finish;
end

initial #410 wr_req = 1;
initial #450 wr_req = 0;
initial #810 wr_req = 1;
initial #850 wr_req = 0;
initial #1210 wr_req = 1;
initial #1250 wr_req = 0;
initial #1610 wr_req = 1;
initial #1650 wr_req = 0;


initial #2000 rd_done = 1;
initial #2014 rd_done = 0;


always #20 wr_clk = !wr_clk;
always #2  rd_clk = !rd_clk;
always #200 reset = 0;
always #9 wr_port = ~wr_port;

queue test_queue(
	.wr_clk(wr_clk), .rd_clk(rd_clk), .reset(reset),
	.wr_port(wr_port), .wr_req(wr_req), .q_full(q_full),
	.rd_port(rd_port), .q_empty(q_empty), .rd_done(!q_empty)
);

queue test_queue_2(
	.wr_clk(rd_clk), .rd_clk(wr_clk), .reset(reset),
	.wr_port(rd_port), .wr_req(!q_empty), .q_full(q_full2),
	.rd_port(rd_port2), .q_empty(q_empty2), .rd_done(rd_done)
);

endmodule

