
// Created by David Guillen Fandos
// david@davidgf.net
// You may use it as long as you share the sources

`define NUM_CRACKERS           4 // Must be even!
`define LOG2_NUM_CRACKERS      2 // LOG2 of the above

`define CMD_RESET         4'h0  // Reset!
`define CMD_SET_MSG_BYTE  4'h1  // Select and set initial values for the message
`define CMD_SEL_MSG_BYTE  4'h2
`define CMD_SET_OFFSET    4'h3  // Set working offset (0 means no salt)
`define CMD_SET_MAX_CHAR  4'h4  // Set max characters to bruteforce
`define CMD_SEL_BYTE_MAP  4'h5  // Select and set bytes in MAP
`define CMD_SET_BYTE_MAP  4'h6
`define CMD_SET_CS_SIZE   4'h7  // Set the charset size write (see driver, need to issue 16 of them)
`define CMD_PUSH_BLOOM    4'h8  // Pushes a byte to the word register
`define CMD_PUSHWR_BLOOM  4'h9  // Pushes a byte to the word register and writes the register to RAM
`define CMD_ZWR_BLOOM     4'hA  // Performs a 32 bit zero write and advances the pointer (N times, where N <= 16)
`define CMD_PUSH_VPIPE_B  4'hB  // Push a byte into vpipe config register
`define CMD_PUSH_VPIPE_OF 4'hC

`define CMD_START         4'hF  // Start! This is, stop resetting devices

`define RESP_HIT          4'h1   // Found a hit!
`define RESP_PING         4'h2   // Just a ping!
`define RESP_FINISHED     4'hF   // All units finished!

