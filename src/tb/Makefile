
runtop:
	iverilog -o testbtop.bin -I.. ../toplevel.v toplevel_tb.v ../md5_pipe.v ../md5-pre.v ../md5-post.v ../uart.v ../cgen.v ../char_map.v ../checker.v ../ram.v ../fifo.v
	vvp testbtop.bin -lx2

test_md5:
	iverilog -o testmd5.bin md5_tb.v ../md5_pipe.v ../md5-pre.v ../md5-post.v
	vvp testmd5.bin

test_chargen:
	iverilog -o testb_chargen.bin chargen_tb.v ../char_gen.v
	vvp testb_chargen.bin

test_uart:
	iverilog -o testbuart.bin uart_tb.v ../uart.v
	vvp testbuart.bin

test_queue:
	iverilog -o testqueue.bin ../queue.v queue_tb.v
	vvp testqueue.bin


