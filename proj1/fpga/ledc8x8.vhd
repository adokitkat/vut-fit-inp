-- Autor reseni: Adam Mudry, xmudry01

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ledc8x8 is
    port (
        RESET, SMCLK : in std_logic;
        ROW, LED     : out std_logic_vector (0 to 7)
    );
end ledc8x8;

architecture main of ledc8x8 is

    signal enable      : std_logic := '0';
    signal freq_count  : std_logic_vector(7 downto 0);
    signal clock_count : std_logic_vector(21 downto 0) := (others => '0');
    signal row_signal  : std_logic_vector(7 downto 0) := "10000000";
    signal led_signal  : std_logic_vector(7 downto 0);
	signal state       : std_logic_vector(1 downto 0) := (others => '0');

begin
	
	-- Citac na znizenie frekvenice  --
    counter: process(SMCLK, RESET)
    begin
        if RESET = '1' then
            freq_count <= (others => '0');
        elsif rising_edge(SMCLK) then
            freq_count <= freq_count + 1;
        end if;
    end process counter;
    enable <= '1' when freq_count = "11111111" else '0';

    -- Bliknutie displeja --
    blink: process(SMCLK, RESET)
    begin

        if (RESET = '1') then
            clock_count <= (others => '0');
        elsif rising_edge(SMCLK) and state /= "10" then
            clock_count <= clock_count + 1;
            if clock_count = "1110000100000000000000" then
                state <= state + 1;
                clock_count <= (others => '0');     
            end if;
        end if;

    end process;

    -- Rotacia riadkov --
    rotation: process(row_signal)
    begin

        if RESET = '1' then
            row_signal <= "10000000";
        elsif rising_edge(SMCLK) and enable = '1' then
            row_signal <= row_signal(0) & row_signal(7 downto 1);
        end if;

    end process;

    -- Zobrazovanie na led displeji --
    display: process(SMCLK, RESET, enable)
    begin
        
        if state = "00" or state = "10" then
		  
		case row_signal is
			when "10000000" => led_signal <= "10011111";
			when "01000000" => led_signal <= "01101111";
			when "00100000" => led_signal <= "00001111";
			when "00010000" => led_signal <= "01101110";
			when "00001000" => led_signal <= "01100100";
			when "00000100" => led_signal <= "11101010";
			when "00000010" => led_signal <= "11101110";
			when "00000001" => led_signal <= "11101110";
			when others => led_signal <= (others => '1');
        end case;
		  
		elsif state = "01" then 
		  
		    led_signal <= (others => '1');
		  
		end if;
		  
    end process;
	 
	ROW <= row_signal;
    LED <= led_signal;

end main;

-- ISID: 75579
