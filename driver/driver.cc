
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

#include <stdio.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <map>
#include <math.h>
#include <stdint.h>
#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <ctime>
#include <chrono>
#include <signal.h>
#include <pthread.h>
#include <assert.h>
#include "constants.h"
#include "util.h"

#ifdef BUILD_FTDI_MODULE
#include "ftdi_device.h"
#endif

#include "file_device.h"
#include "uart_device.h"
#include "hash.h"

#define NUM_PIPES    4  // 4 hashing pipes per cracker device
#define NUM_SUBDEVS  2  // 2 hashing cracker subdevices per device (port)
#define NUM_VPIPES   2  // 2 virtual pipes per physical pipe

// Global config for the run
bool verbose = false;
std::string map;
std::string prefix, postfix;
unsigned char max_chars, max_chars_device;
bool force_end = false;
bool cracking = false;
unsigned start_offset = 0;

pthread_mutex_t globallock = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t stdlock = PTHREAD_MUTEX_INITIALIZER; 

// Calculate the number of chars to brute to get ~15min proc. time @ 160Mhz
int bruteN(int ndev) {
	const float mins = 1.0f;
	const float freq = 160e6 / NUM_VPIPES;

	int ideal = ceil(log(mins*60*freq)/log(map.size()));

	// Make sure we give everyone work share
	int npipes = NUM_VPIPES * NUM_PIPES * NUM_SUBDEVS * ndev;
	int minN = max_chars - ceil(log(npipes)/log(map.size()));
	if (minN < 1) minN = 1;

	std::cerr << "Ideally we would bruteforce " << ideal << " chars, but we need to do " << minN << std::endl;

	return std::min(minN, ideal);
}

// Produce a CMD targeting some cracker with the mentioned payload
uint16_t controlcmd(int cmd, int tgt, uint8_t payload) {
	return ((cmd & 0xF) << 12) | ((tgt & 0xF) << 8) | payload;
}

#define show(x) printf("%02x\n%02x\n", x & 0xFF, x >> 8)

std::vector <uint16_t> genBloomID(std::string hashfile) {
	std::vector <uint16_t> ret;

	// Now program the bloom filters!
	std::ifstream hfile(hashfile);
	std::string hashstr;
	unsigned hashes = 0;
	while (hfile >> hashstr) {
		if (hashstr.size() != 32) continue;
		unsigned int hash_c = hex2int(hashstr.substr(16, 8));
		unsigned int hash_d = hex2int(hashstr.substr(24, 8));
		insert_word(hash_c, hash_d);
		solved_hashes[hashstr] = "";
		hashes++;
	}
	hfile.close();

	std::cerr << hashes << " hash(es) loaded" << std::endl;

	// Output byte set commands for the bloom filters
	// Each byte write moves the pointers forward
	// Previous reset will move pointers back to 0,0
	int lastz = 0;
	for (unsigned i = 0; i < 16; i++) {
		for (unsigned j = 0; j < 16*1024; j += 32) {
			unsigned int r = getfilter32(i, j);

			if ((r != 0 and lastz != 0) || lastz == 8) {
				ret.push_back(controlcmd(CMD_ZWR_BLOOM, 0, lastz-1));
				lastz = 0;
			}

			if (r) {
				// Push four bytes
				ret.push_back(controlcmd(CMD_PUSH_BLOOM,   0, (r >> 24) & 0xFF));
				ret.push_back(controlcmd(CMD_PUSH_BLOOM,   0, (r >> 16) & 0xFF));
				ret.push_back(controlcmd(CMD_PUSH_BLOOM,   0, (r >>  8) & 0xFF));
				ret.push_back(controlcmd(CMD_PUSHWR_BLOOM, 0, (r >>  0) & 0xFF));
			}else{
				// Just push a zero!
				lastz++;
			}
		}
	}

	if (lastz)
		ret.push_back(controlcmd(CMD_ZWR_BLOOM, 0, lastz-1));

	return ret;
}

std::vector <uint16_t> setCharMap(std::string map) {
	std::vector <uint16_t> ret;

	// This sets the map RAM
	for (unsigned i = 0; i < map.size(); i++) {
		ret.push_back(controlcmd(CMD_SEL_BYTE_MAP, 0, (unsigned char)i));
		ret.push_back(controlcmd(CMD_SET_BYTE_MAP, 0, (unsigned char)map[i]));
	}

	// And then fix the count size for flip detection
	ret.push_back(controlcmd(CMD_SET_CS_SIZE, 0, map.size()));

	return ret;
}

std::vector <uint16_t> generateInitialMessage(unsigned cid, unsigned int map_id, unsigned thread) {
	std::vector <uint16_t> ret;

	// Only works for vpipes = 2
	assert(NUM_VPIPES == 2);

	// Generate chunks to bruteforce
	std::vector <std::string> worker_chunks = getWorkerChunks(map_id, max_chars, max_chars_device, map, NUM_VPIPES);

	// Find where the chunks differ
	assert(worker_chunks.size() == NUM_VPIPES);
	unsigned char vpipeid = ~0;
	worker_chunks[0].size() == worker_chunks[1].size();

	for (unsigned p = 0; p < worker_chunks[0].size(); p++) {
		if (worker_chunks[0][p] != worker_chunks[1][p]) {
			assert(vpipeid != ~0);
			vpipeid = p;
		}
	}
	assert(vpipeid != ~0);

	unsigned pipe_cid = cid / NUM_VPIPES;

	// Program the VPIPE char byte & offset (each pipe may work at a different offset!)
	unsigned char vpipe_offset = prefix.size() + max_chars_device + vpipeid;
	assert(vpipe_offset < 64);
	ret.push_back(controlcmd(CMD_PUSH_VPIPE_OF, pipe_cid, vpipe_offset));

	for (unsigned i = 0; i < NUM_VPIPES; i++)
		ret.push_back(controlcmd(CMD_PUSH_VPIPE_B, pipe_cid, worker_chunks[i][vpipeid]));

	{
		// Initial & base message
		unsigned int length = prefix.size() + max_chars + postfix.size();
		unsigned char msg[64];
		for (unsigned i = 0; i < 64; i++) {
			if (i < prefix.size())
				msg[i] = prefix[i];
			else if (i < prefix.size() + max_chars_device)
				msg[i] = map[0];
			else if (i < prefix.size() + max_chars)
				// Fill with our mapID
				msg[i] = worker_chunks[0][i - prefix.size() - max_chars_device];
			else if (i < prefix.size() + max_chars + postfix.size())
				msg[i] = postfix[i - prefix.size() - max_chars];
			else if (i == prefix.size() + max_chars + postfix.size())
				msg[i] = 0x80;
			else if (i >= 64-8 && i < 64-4) // Beware 32 bit shift!
				msg[i] = (length*8) >> (8*(i-(64-8)));
			else
				msg[i] = 0;

			ret.push_back(controlcmd(CMD_SEL_MSG_BYTE, pipe_cid, i));
			ret.push_back(controlcmd(CMD_SET_MSG_BYTE, pipe_cid, msg[i]));
		}

		if (verbose) {
			pthread_mutex_lock(&stdlock);
			std::cerr << "Initial message for pipe " << pipe_cid << " (thread " << thread << ") ";
			for (unsigned i = 0; i < length; i++)
				fprintf(stderr, "%c", msg[i]);
			std::cerr << std::endl << std::flush;
			pthread_mutex_unlock(&stdlock);
		}
	}

	if (verbose) {
		pthread_mutex_lock(&stdlock);
		std::cerr << "Virtual pipe toogles char @ " << (int)vpipe_offset << " values (";
		std::cerr << worker_chunks[0][vpipeid] << "/" << worker_chunks[1][vpipeid] << ")" << std::endl;
		pthread_mutex_unlock(&stdlock);
	}

	return ret;
}

std::vector<Device*> devices;

void exit_driver(int) {
	// Make sure to reset the thing before leaving 
	// otherwise it won't stop working!
	force_end = true;
	if (!cracking)
		exit(0);
}

void * worker(void * data) {
	Device * dev = (Device*)data;

	int outer_loop_comb = pow(map.size(), (max_chars-max_chars_device));

	// Work sharing
	unsigned start = NUM_VPIPES * NUM_PIPES * NUM_SUBDEVS * (dev->dnum + start_offset);
	unsigned step  = NUM_VPIPES * NUM_PIPES * NUM_SUBDEVS * Device::device_counter;
	unsigned maxd  = ((outer_loop_comb + step - 1)/step)*step;

	std::cerr << "Started device thread " << dev->dnum << " (" << start << ", " << step << ", " << maxd << ")" << std::endl;

	// Pipe ID is:   [di1 di0 pi1 pi0 vpi1 vpi0]
	// Where di1,di0 identifies the subdevice
	// pi1,pi0 identifies the pipe ID and
	// vpi1,vpi0 identifies the virtual pipe
	
	//sleep(dev->dnum*16);

	// Now keep launching jobs once they are finished
	for (unsigned i = start; i < maxd && !force_end; i += step) {
		std::vector <uint16_t> program_seq_pipe;

		// Reset device!
		program_seq_pipe.push_back(controlcmd(CMD_RESET, 0, 0));
		program_seq_pipe.push_back(controlcmd(CMD_RESET, 4, 0));

		for (unsigned n = 0; n < NUM_VPIPES * NUM_PIPES * NUM_SUBDEVS; n += NUM_VPIPES) {
			// Do it once per subpipe, since subpipes share the same physical pipe
			program_seq_pipe = concat(program_seq_pipe, generateInitialMessage(n, i + n, dev->dnum));
		}

		// Send work!
		dev->write(&program_seq_pipe[0], program_seq_pipe.size()*2);

		// Start the show
		uint16_t start1 = controlcmd(CMD_START, 0, 0);
		uint16_t start2 = controlcmd(CMD_START, 4, 0);
		dev->write(&start1, 2);
		sleep(2);
		dev->write(&start2, 2);

		// Wait for responses
		int next = NUM_SUBDEVS;
		while (next > 0 && !force_end) {
			unsigned char response[7];
			int r = 0;
			while (r < 7) {
				int res = dev->read(&response[r], 7 - r);
				if (res > 0)
					r += res;
				if (res <= 0)
					std::cerr << "Error reading serial port!" << std::endl;
			}

			uint64_t payload = 0;
			for (int j = 5; j >= 0; j--)
				payload = (payload << 8ULL) | response[j];

			unsigned char resp_cmd = response[6] >> 4;
			unsigned int  resp_cracker = response[6] & 0xF;

			pthread_mutex_lock(&globallock);
			switch (resp_cmd) {
			case RESP_HIT: {
				auto candidates = hit2pwd(resp_cracker*NUM_VPIPES + i, payload, map, max_chars, max_chars_device, NUM_VPIPES);
				bool found = false;
				for (auto pt: candidates) {
					std::string plaintext = prefix + pt + postfix;
					if (validatehash(plaintext)) {
						std::cerr << currtime();
						std::cerr << "Got a hit! (" << dev->dnum << "," << resp_cracker << ") " << plaintext << std::endl;
						found = true;
					}
				}
				if (!found) {
					//std::cerr << "Got a false hit! (" << dev->dnum << "," << resp_cracker << ") " << plaintext << std::endl;
					std::cerr << currtime();
					std::cerr << "Got a false hit! (" << dev->dnum << "," << resp_cracker << ") " << candidates[0] << " " << i << std::endl;
				}

				} break;
			case RESP_PING:
				//std::cerr << currtime();
				//std::cerr << "PING (" << dev->dnum << "," << resp_cracker << ")" << std::endl;
				break;
			case RESP_FINISHED:
				std::cerr << currtime();
				std::cerr << "Batch finished! (" << dev->dnum << "," << resp_cracker << ") " << payload << std::endl;
				next--;
				break;
			default:
				std::cerr << currtime();
				std::cerr << "Malformed response!!! " << dev->dnum << std::endl;
				fprintf(stderr, "%02x%02x%02x%02x%02x%02x%02x", response[6], response[5], response[4], response[3], response[2], response[1], response[0]);
				break;
			}
			pthread_mutex_unlock(&globallock);
		}	
	}

	return NULL;
}

int main(int argc, char ** argv) {
	signal(SIGINT, exit_driver);

	if (argc < 4) {
		std::cerr << "Missing arguments! Usage:" << std::endl;
		std::cerr << argv[0] << " charset num-chars hash_file.txt [-v] [-pre prefix-salt] [-post postfix-salt] [-test file.txt] [-dev device/ftdi]" << std::endl;
		exit(1);
	}
	std::string charset = argv[1];
	max_chars = atoi(argv[2]);
	std::string hashfile = argv[3];
	std::string testfile, device_path;
	hash_init();

	for (unsigned p = 4; p < argc; p++) {
		if (std::string(argv[p]) == "-pre")
			prefix = std::string(argv[p+1]);
		if (std::string(argv[p]) == "-post")
			postfix = std::string(argv[p+1]);
		if (std::string(argv[p]) == "-test")
			testfile = std::string(argv[p+1]);
		if (std::string(argv[p]) == "-dev")
			device_path = std::string(argv[p+1]);
		if (std::string(argv[p]) == "-v")
			verbose = true;
		if (std::string(argv[p]) == "-s")
			start_offset = atoi(argv[p+1]);
	}

	// Expand the charset
	// Examples are: a-zA-Z0-9 or abcde0-9
	for (unsigned i = 0; i < charset.size(); i++) {
		// Escape dash with backslash
		if (i+1 < charset.size() and charset[i] == '\\' and charset[i+1] == '-') {
			map += '-';
			i++;
		}
		else if (i+2 < charset.size() and charset[i+1] == '-') {
			for (char c = charset[i]; c <= charset[i+2]; c++) {
				map += c;
			}
			i += 2;
		}
		else
			map += charset[i];
	}
	unsigned long long combinations = pow(map.size(), (int)max_chars);
	double etime = combinations / 1e9 / 3600.0f;
	std::cerr << "Charset to test " << map << " (" << map.size() << " characters)" << std::endl;
	std::cerr << "Testing " << (int)max_chars << " characters, this is " << combinations << " combinations (" << etime << " hours on 1 FPGA at 1GH/s)" << std::endl;

	// Device discovery!
	if (testfile.size())
		devices.push_back(new FileDevice(testfile.c_str()));
	else if (device_path == "ftdi")
		#ifdef BUILD_FTDI_MODULE
		devices = FTDIDevice::getAllDevs();
		#else
		std::cerr << "No FTDI support built in!" << std::endl;
		#endif
	else
		devices.push_back(new UARTDevice(device_path.c_str()));

	start_offset *= devices.size();

	// Work division
	max_chars_device = bruteN(devices.size());
	if (max_chars_device >= max_chars)
		max_chars_device = max_chars-1;
	std::cerr << "Bruteforcing " << (int)max_chars_device << " chars at a time" << std::endl;

	// Generate init sequence
	std::vector <uint16_t> program_seq;

	program_seq.push_back(controlcmd(CMD_RESET, 0, 0));

	// Setup bloom filters
	program_seq = concat(program_seq, genBloomID(hashfile));

	// Setup character map (fixed for every position for now)
	program_seq = concat(program_seq, setCharMap(map));

	// Set offset to the size of the prefix
	program_seq.push_back(controlcmd(CMD_SET_OFFSET, 0, prefix.size()));
	// Num chars to bruteforce! (Chars - 1)
	program_seq.push_back(controlcmd(CMD_SET_MAX_CHAR, 0, max_chars_device));

	// Do initial programming
	std::cerr << devices.size() << " device(s) found!" << std::endl;
	for (auto dev: devices) {
		dev->flush();
		dev->write(&program_seq[0], program_seq.size()*2);
	}

	double hashpower = (150e6 * 4 * 2 * devices.size()); // Hash power estimate @ 150MHz
	etime = combinations / hashpower / 3600.0f;
	std::cerr << "Estimate runtime " << etime << " hours" << std::endl;

	std::cerr << "Setup done, starting to bruteforce!" << std::endl;
	cracking = true;

	// Setup worker threads
	int num_workers = NUM_PIPES * NUM_SUBDEVS * devices.size();

	pthread_t tpool[num_workers];
	for (unsigned i = 0; i < devices.size(); i++)
	    pthread_create (&tpool[i], NULL, worker, (void *)devices[i]);

	for (unsigned i = 0; i < devices.size(); i++)
	    pthread_join (tpool[i], NULL);

	// Reset device!
	for (auto dev: devices) {
		uint16_t code = controlcmd(CMD_RESET, 0, 0);
		dev->write(&code, sizeof(code));
	}

	// Print stdout the hashes!
	for (auto hash: solved_hashes)
		if (hash.second.size())
			std::cout << hash.first << " " << hash.second << std::endl;
}

