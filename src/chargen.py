
charlen = 16
num_chars = 10

value = [0]*charlen
updwn = [0]*charlen

for i in range(charlen):
	next_value = [ value[i] - 1 if updwn[i] else value[i] + 1]
	

