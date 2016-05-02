
for cc in "AB":
	for i in range(8):
		print "assign %s_indices[%d] = {" % (cc, i),

		l = []
		idx = 3*(i % 4)
		for j in range(13):
			extra = 32 if i < 4 else 0
			l.append("%s_hash[%d]" % (cc, idx + extra))
			idx = (idx + 13) % 32

		print ",".join(reversed(l)) + " };"

for i in range(8):
	print """ram_module #(.DATA(1), .ADDR(13)) bloom_ram_%d (
	.a_clk(clk), .a_wr(wr_en & (filter_id == %d)),
	.a_addr(wr_en ? in_addr : A_indices[%d]), .a_din(in_val), .a_dout(A_bit[%d]),

	.b_clk(clk), .b_wr(1'b0),
	.b_addr(B_indices[%d]), .b_din(1'b0), .b_dout(B_bit[%d])
);""" % (i, i,i,i,i,i)

