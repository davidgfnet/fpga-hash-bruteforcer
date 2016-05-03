----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:04:23 03/28/2012 
-- Design Name: 
-- Module Name:    FLASHER - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY FLASHER IS
    PORT ( CLOCK 			: IN  STD_LOGIC;
           RESET_N 		: IN  STD_LOGIC;
           COUNT 			: IN  INTEGER RANGE 0 TO 250000000;
			  FLASHOUT		: OUT	STD_LOGIC
			  );
END FLASHER;

ARCHITECTURE BEHAVIORAL OF FLASHER IS
--																			  
  SIGNAL FLASH_COUNTER 					 : INTEGER RANGE 0 TO 250000000;
  SIGNAL FLASH_BIT						 : STD_LOGIC;
--
BEGIN
--
PROCESS (CLOCK, RESET_N, COUNT)
	BEGIN
	IF CLOCK'EVENT AND CLOCK = '1' THEN
		IF RESET_N = '0' THEN
			FLASH_COUNTER <= COUNT;
			FLASH_BIT <= '0';
		ELSE
			IF (FLASH_COUNTER = 0) THEN
				FLASH_COUNTER <= COUNT;
				FLASH_BIT <= FLASH_BIT XOR '1';
			ELSE
				FLASH_COUNTER <= FLASH_COUNTER - 1;
				FLASH_BIT <= FLASH_BIT;
			END IF;
		END IF;
	END IF;
END PROCESS;
--
FLASHOUT	<= FLASH_BIT;
--
END BEHAVIORAL;

