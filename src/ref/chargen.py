
num_chars = 6
charset_len = 10

counters_val = [0] * num_chars
counters_upd = [0] * num_chars
ptr = 0
overflows = [0] * num_chars

for w in range(10000):
	print ""," ".join(map(lambda x: str(x),counters_val)),w

	if counters_upd[ptr] == 0:
		counters_val[ptr] = counters_val[ptr] + 1
		overflow = (counters_val[ptr] == charset_len - 1)
	else:
		counters_val[ptr] = counters_val[ptr] - 1
		overflow = counters_val[ptr] == 0

	overflows[ptr] = overflow

	num = 0
	for i in range(num_chars):
		if overflows[i]:
			num = i+1
			overflows[i] = False
			counters_upd[i] = 1 - counters_upd[i]
		else:
			break

	ptr = num


