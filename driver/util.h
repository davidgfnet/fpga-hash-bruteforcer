
#include <openssl/md5.h>

#define SWAP_UINT32(x) (((x) >> 24) | (((x) & 0x00FF0000) >> 8) | (((x) & 0x0000FF00) << 8) | ((x) << 24))

#define N_TWEAK (-2)  // This should be zero, if RTL does not have any bug

static std::map <std::string, std::string> solved_hashes;

template <typename T>
inline T concat(const T & a, const T & b) {
	T ret;
	ret.insert( ret.end(), a.begin(), a.end());
	ret.insert( ret.end(), b.begin(), b.end());
	return ret;
}

static bool validatehash(std::string plaintext) {
	unsigned char digest[MD5_DIGEST_LENGTH];
	MD5((unsigned char*)plaintext.c_str(), plaintext.size(), (unsigned char*)&digest);

	char hashstr[33];
	for(int i = 0; i < 16; i++)
		sprintf(&hashstr[i*2], "%02x", (unsigned int)digest[i]);

	bool result = (solved_hashes.find(hashstr) != solved_hashes.end());
	if (result)
		solved_hashes[hashstr] = plaintext;
	return result;
}

static std::string currtime() {
	std::chrono::system_clock::time_point today = std::chrono::system_clock::now();
	time_t tt = std::chrono::system_clock::to_time_t (today);
	return std::ctime(&tt);
}

static unsigned int hex2int(std::string hex) {
	unsigned int ret = 0;
	while (hex.size()) {
		ret <<= 4;
		if (hex[0] >= '0' && hex[0] <= '9')
			ret |= hex[0] - '0';
		else if (hex[0] >= 'a' && hex[0] <= 'f')
			ret |= hex[0] - 'a' + 10;
		hex = hex.substr(1);
	}
	// Endian swap
	return SWAP_UINT32(ret);
}

static std::vector<std::string> getWorkerChunks(unsigned map_id, unsigned max_chars, unsigned max_chars_device, std::string map, unsigned nvpipes) {
	// Generate chunks to bruteforce
	std::vector <std::string> worker_chunks;
	for (unsigned mmid = map_id; mmid < map_id + nvpipes; mmid++) {
		unsigned wmmid = mmid;
		std::string worker_chunk;
		for (int i = 0; i < max_chars - max_chars_device; i++) {
			int c = wmmid % map.size();
			if ((wmmid / map.size()) % 2 == 0)
				worker_chunk += map[c];
			else
				worker_chunk += map[map.size() - c - 1];
		
			wmmid = wmmid / map.size();
		}

		worker_chunks.push_back(worker_chunk);
	}

	return worker_chunks;
}

// Convert sequence id in password (seq ids age generated using generalized gray code)
static std::vector<std::string> hit2pwd(unsigned cid, uint64_t n, std::string charset, int numchars, int numchars_dev, unsigned nvpipes) {
	n += N_TWEAK;
	n = n / 2;

	int charlen = charset.size();
	std::vector<char> res;

	for (unsigned i = 0; i < numchars_dev; i++) {
		int c = n % charlen;
		if ((n / charlen) % 2 == 0)
			res.push_back(charset[c]);
		else
			res.push_back(charset[charlen - c - 1]);

		n /= charlen;
	}

	std::string ress;
	for (auto c: res)
		ress = ress + c;

	// Calculate device postfix
	std::vector <std::string> worker_chunks = getWorkerChunks(cid, numchars, numchars_dev, charset, nvpipes);

	std::vector <std::string> vres;
	for (auto wchunk: worker_chunks)
		vres.push_back(ress + wchunk);

	return vres;
}

static std::vector<std::string> hit2pwd__(unsigned cid, uint64_t n, std::string charset, int numchars, int numchars_dev, unsigned nvpipes) {
	std::vector<std::string> ret;

	for (int i = -10; i < 10; i++) {
		auto res = hit2pwd(cid, ((signed)n)+i, charset, numchars, numchars_dev, nvpipes);
		for (auto elem: res)
			ret.push_back(elem);
	}

	return ret;
}


