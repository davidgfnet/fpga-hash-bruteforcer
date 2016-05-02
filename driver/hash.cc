
// Hash function
// We use 8 bloom filters (1 hash fn each)
// Each bloom filter is 8kbit wide (13 bit addrs)

#include <vector>
#include <string.h>
#include <openssl/md5.h>
#include <stdint.h>

uint64_t rotl(uint64_t n, uint64_t a) {
	a = a & 63;
	return (n << a) | (n >> (64-a));
}

unsigned int compress2(unsigned int n) {
	unsigned int r = 0;
	for (int i = 0; i < 32; i+= 2)
		r |= (((n >> i) & 1) << (i/2));
	return r;
}

uint64_t compress3(uint64_t n) {
	uint64_t r = 0;
	for (int i = 0; i < 64; i+= 3)
		r |= (((n >> i) & 1) << (i/3));
	return r;
}

uint64_t compress4(uint64_t n) {
	uint64_t r = 0;
	for (int i = 0; i < 64; i+= 4)
		r |= (((n >> i) & 1) << (i/4));
	return r;
}

// Bloom num is the hash fn num (0 .. 15)
// We have the two 32 bit LSB for the hash (C & D)
unsigned bloom_idx16(unsigned bloom_num, unsigned int hash_c, unsigned int hash_d) {
	uint64_t hash = (((uint64_t)hash_c)<<32) | ((uint64_t)hash_d);

	if (bloom_num < 6) {
		hash = rotl(hash, 14*bloom_num);
		return (hash >> (64-14)) & 0x3FFF;
	}
	if (bloom_num < 12) {
		bloom_num = bloom_num - 6;
		uint64_t pa = rotl(hash, 14*bloom_num + 10);
		uint64_t pb = rotl(hash, 14*(bloom_num+1) + 10);
		return ((pa ^ pb) >> (64-14)) & 0x3FFF;
	}
	if (bloom_num == 12) {
		unsigned int pa = (hash_c & 0xAAAAAAAA);
		unsigned int pb = (hash_c & 0x55555555);
		unsigned int r = (pa >> 1) ^ pb;
		r = compress2(r);
		return (r >> 2) & 0x3FFF;
	}
	if (bloom_num == 13) {
		unsigned int pa = (hash_d & 0xAAAAAAAA);
		unsigned int pb = (hash_d & 0x55555555);
		unsigned int r = (pa >> 1) ^ pb;
		r = compress2(r);
		return (r >> 2) & 0x3FFF;
	}
	if (bloom_num == 14) {
		hash = rotl(hash, 64-11); // Rotate right 11
		uint64_t pa = (hash & 0x4924924924924924ULL);
		uint64_t pb = (hash & 0x2492492492492492ULL);
		uint64_t pc = (hash & 0x9249249249249249ULL);
		uint64_t r = (pa >> 2) ^ (pb >> 1) ^ pc;
		r = compress3(r);
		return r & 0x3FFF;
	}
	if (bloom_num == 15) {
		hash = rotl(hash, 64-4); // Rotate right 4
		uint64_t pa = (hash & 0x1111111111111111ULL);
		uint64_t pb = (hash & 0x2222222222222222ULL);
		uint64_t pc = (hash & 0x4444444444444444ULL);
		uint64_t pd = (hash & 0x8888888888888888ULL);
		uint64_t r = (pd >> 3) ^ (pc >> 2) ^ (pb >> 1) ^ pa;
		r = compress4(r);
		return r & 0x3FFF;
	}
}

std::vector < std::vector <bool> > bloom_filters;
void hash_init() {
	for (unsigned i = 0; i < 16; i++)
		bloom_filters.push_back(std::vector <bool> (16*1024));
}

void insert_word(unsigned int hash_c, unsigned int hash_d) {
	for (unsigned i = 0; i < 16; i++)
		bloom_filters[i][bloom_idx16(i, hash_c, hash_d)] = true;
}

// Little endian bits!
unsigned int getfilter32(int f, int p) {
	unsigned int ret = 0;
	for (int i = 0; i < 32; i++) {
		if (bloom_filters[f][p+i])
			ret |= (1 << (i));
	}
	return ret;
}


