
#define CMD_RESET         0x0  //
#define CMD_SET_MSG_BYTE  0x1  // Has target
#define CMD_SEL_MSG_BYTE  0x2  // Has target
#define CMD_SET_OFFSET    0x3  //
#define CMD_SET_MAX_CHAR  0x4  //
#define CMD_SEL_BYTE_MAP  0x5  //
#define CMD_SET_BYTE_MAP  0x6  //
#define CMD_SET_CS_SIZE   0x7  //
#define CMD_PUSH_BLOOM    0x8  //
#define CMD_PUSHWR_BLOOM  0x9  //
#define CMD_ZWR_BLOOM     0xA  //
#define CMD_PUSH_VPIPE_B  0xB  //
#define CMD_PUSH_VPIPE_OF 0xC  //

#define CMD_START         0xF  //

#define RESP_HIT          0x1   // Found a hit!
#define RESP_PING         0x2   // PING!
#define RESP_FINISHED     0xF   // All units finished!

