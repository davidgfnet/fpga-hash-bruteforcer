
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ftdi.h>

#define VENDOR_FTDI   0x0403
#define DEVICE_DEF    0x8350
#define mgr_channel   INTERFACE_B    // From 1 to 4 (cause we are computer scientists!)

#define fatal(...) { fprintf(stderr,  __VA_ARGS__); exit(1); }

#define POWER_ARRAY 0x0
#define JTAG_MODE   0x1
#define FAN_SENSE   0x2
#define RESET_FPGA  0x3

void writereg(struct ftdi_context * ftdi_handle, int rnum, int value) {
	unsigned char command = 0x80 | ((rnum & 0x7) << 4) | (value & 0xF);
	int wr = ftdi_write_data(ftdi_handle, &command, 1);
	if (wr != 1)
		fatal("ERROR ftdi_write_data: %s\n", ftdi_get_error_string(ftdi_handle));
}

unsigned char readreg(struct ftdi_context * ftdi_handle, int rnum) {
	unsigned char command = (rnum & 0x7) << 4;
	int wr = ftdi_write_data(ftdi_handle, &command, 1);
	if (wr != 1)
		fatal("ERROR ftdi_write_data: %s\n", ftdi_get_error_string(ftdi_handle));

	unsigned char reply;
	int rd;
	while ((rd = ftdi_read_data(ftdi_handle, &reply, 1)) == 0);
	if (rd != 1)
		fatal("ERROR ftdi_read_data: %s\n", ftdi_get_error_string(ftdi_handle));

	return reply;
}

#define ARGV_DNUM 1
#define ARGV_CMD  2
#define ARGV_ARG1 3

int main(int argc, char ** argv) {
	libusb_device * dev_open = NULL;
	{
		struct ftdi_context * listhandle = ftdi_new();
		struct ftdi_device_list * devlist;
		if (ftdi_usb_find_all(listhandle, &devlist, VENDOR_FTDI, DEVICE_DEF) < 0)
			fatal("ERROR ftdi_usb_find_all: %s\n", ftdi_get_error_string(listhandle));

		int dnum = atoi(argv[ARGV_DNUM]);
		struct ftdi_device_list * curdev;
		for (curdev = devlist; curdev != NULL; curdev = curdev->next) {
			if (dnum == 0) {
				dev_open = curdev->dev;
				break;
			}
			dnum--;
		}

		if (!dev_open)
			fatal("Could not open device number %d\n", dnum);
	}

	struct ftdi_context *ftdi_handle = ftdi_new();

	if (ftdi_set_interface(ftdi_handle, (ftdi_interface)mgr_channel) < 0)
		fatal("ERROR ftdi_set_interface: %s\n", ftdi_get_error_string(ftdi_handle));

	// Open device
	if (ftdi_usb_open_dev(ftdi_handle, dev_open) < 0)
		fatal("ERROR ftdi_usb_open: %s\n", ftdi_get_error_string(ftdi_handle));

	if (ftdi_set_bitmode(ftdi_handle, 0x00, BITMODE_RESET) < 0)
		fatal("ERROR ftdi_set_bitmode: %s\n", ftdi_get_error_string(ftdi_handle));

	if (ftdi_usb_purge_buffers(ftdi_handle) < 0)
		fatal("ERROR ftdi_usb_purge_buffers: %s\n", ftdi_get_error_string(ftdi_handle));

	ftdi_setflowctrl(ftdi_handle, SIO_DISABLE_FLOW_CTRL);

	if (ftdi_set_line_property(ftdi_handle, BITS_8, STOP_BIT_1, NONE ) < 0)
		fatal("ERROR ftdi_set_line_property: %s\n", ftdi_get_error_string(ftdi_handle));

	if (ftdi_set_baudrate(ftdi_handle, 115200) < 0)
		fatal("ERROR ftdi_set_baudrate: %s\n", ftdi_get_error_string(ftdi_handle));


	if (argc == 2 || strcmp(argv[ARGV_CMD], "status") == 0) {
		// Read registers
		int power_state = readreg(ftdi_handle, POWER_ARRAY);
		int jtag_mode   = readreg(ftdi_handle, JTAG_MODE);
		int fan_sense   = readreg(ftdi_handle, FAN_SENSE) * 60;
		int reset_en    = readreg(ftdi_handle, RESET_FPGA);

		printf("Power state is 0x%01x:", power_state);
		for (int i = 0; i < 4; i++)
			printf(" CORE%d:%s", i, (power_state & (1 << i)) ? "ON" : "OFF");
		printf("\n");

		printf("JTAG is %s\n", jtag_mode ? "ENABLED" : "DISABLED");

		printf("FAN at %d rpm\n", fan_sense);

		printf("RESET is %s\n", reset_en ? "ENABLED" : "DISABLED");
	}
	else if (strcmp(argv[ARGV_CMD], "poweron") == 0) {
		writereg(ftdi_handle, POWER_ARRAY, 0xF);
	}
	else if (strcmp(argv[ARGV_CMD], "poweron1") == 0) {
		writereg(ftdi_handle, POWER_ARRAY, 0x8);
	}
	else if (strcmp(argv[ARGV_CMD], "poweron2") == 0) {
		writereg(ftdi_handle, POWER_ARRAY, 0xC);
	}
	else if (strcmp(argv[ARGV_CMD], "poweroff") == 0) {
		writereg(ftdi_handle, POWER_ARRAY, 0x0);
	}
	else if (strcmp(argv[ARGV_CMD], "jtag") == 0) {
		if (argc < 3)
			fatal("Need enable/disable!\n");
		int val = strcmp(argv[ARGV_ARG1], "enable") == 0 ? 1 : 0;
		writereg(ftdi_handle, JTAG_MODE, val);
	}
	else if (strcmp(argv[ARGV_CMD], "reset") == 0) {
		if (argc < 3)
			fatal("Need enable/disable!\n");
		int val = strcmp(argv[ARGV_ARG1], "enable") == 0 ? 1 : 0;
		writereg(ftdi_handle, RESET_FPGA, val);
	}

}


