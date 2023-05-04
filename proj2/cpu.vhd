-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2019 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Adam Múdry (xmudry01)
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
  port (
    CLK   : in std_logic;  -- hodinovy signal
    RESET : in std_logic;  -- asynchronni reset procesoru
    EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
    DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
    DATA_WDATA : out std_logic_vector(7 downto 0);  -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
    DATA_RDATA : in  std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
    DATA_RDWR  : out std_logic;                     -- cteni (0) / zapis (1)
    DATA_EN    : out std_logic;                     -- povoleni cinnosti
   
   -- vstupni port
    IN_DATA   : in  std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
    IN_VLD    : in  std_logic;                      -- data platna
    IN_REQ    : out std_logic;                      -- pozadavek na vstup data
   
   -- vystupni port
    OUT_DATA : out std_logic_vector(7 downto 0);    -- zapisovana data
    OUT_BUSY : in  std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
    OUT_WE   : out std_logic                        -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
  );
end cpu;

-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

 -- zde dopiste potrebne deklarace signalu

  signal cnt_out  : std_logic_vector(7 downto 0) := (others => '0');
  signal cnt_inc  : std_logic;
  signal cnt_dec  : std_logic;

  signal pc_out  : std_logic_vector(12 downto 0) := (others => '0');
  signal pc_inc  : std_logic;
  signal pc_dec  : std_logic;

  signal ptr_out : std_logic_vector(12 downto 0) := "1000000000000";
  signal ptr_inc : std_logic;
  signal ptr_dec : std_logic;

  signal sel1    : std_logic;
  signal sel2    : std_logic;
  signal mx2_out : std_logic_vector(12 downto 0);
  signal sel3    : std_logic_vector(1 downto 0) := "11";

  type fsm_state is (
    state_idle, state_fetch,
    state_ptr_inc, state_ptr_dec,
    state_data_inc, state_data_inc_next, state_data_dec, state_data_dec_next,  
    state_get,
    state_print, state_print_next, 
    state_while1_start, state_while2_start, state_while3_start, state_while4_start, state_while5_start,
    state_while1_end, state_while2_end, state_while3_end, state_while4_end, state_while5_end,
    state_store, state_store_next, state_load, state_load_next,
    state_halt, state_nop,
    state_decode
  );
  signal prev_state : fsm_state;
  signal next_state : fsm_state;

  type instruction_type is (
    cell_data_inc, cell_data_dec,
    cell_ptr_inc, cell_ptr_dec,
    while_start, while_end,
    print, get, 
    store, load,
    halt, nop
  );
  signal instruction : instruction_type;

begin

 -- zde dopiste vlastni VHDL kod

 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --   - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --   - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.

  cnt : process(CLK, RESET, cnt_out, cnt_inc, cnt_dec)
  begin
      if(RESET = '1') then
        cnt_out <= (others => '0');
      
      elsif(rising_edge(CLK)) then
        
        if(cnt_inc = '1') then
          cnt_out <= cnt_out + 1;

        elsif(cnt_dec = '1') then
          cnt_out <= cnt_out - 1;
        
          end if;
      end if;
  end process;

  -- pc counter
  pc : process(CLK, RESET, pc_out, pc_inc, pc_dec)
    begin
        if(RESET = '1') then
          pc_out <= (others => '0');

        elsif(rising_edge(CLK)) then

            if(pc_inc = '1') then
              if (pc_out = "0111111111111") then
                pc_out <= (others => '0');
              else
               pc_out <= pc_out + 1;
              end if;

            elsif(pc_dec = '1') then
              if (pc_out = "0000000000000") then
                pc_out <= "0111111111111";
              else
                pc_out <= pc_out - 1;
              end if;
             
            end if;
        end if;
    end process;
  
  -- ptr counter
  ptr : process(CLK, RESET, ptr_out, ptr_inc, ptr_dec)
    begin
        if (RESET = '1') then
          ptr_out <= "1000000000000";

        elsif (rising_edge(CLK)) then
            if (ptr_inc = '1') then
              if (ptr_out = "1111111111111") then
                ptr_out <= "1000000000000";
              else
                ptr_out <= ptr_out + 1;
              end if;

            elsif (ptr_dec = '1') then
              if (ptr_out = "1000000000000") then
                ptr_out <= "1111111111111";
              else
                ptr_out <= ptr_out - 1;
              end if;

            end if;
        end if;
    end process;

  decoder: process (DATA_RDATA) -- CLK, RESET ?
    begin
      case (DATA_RDATA) is
        when X"3E"  => instruction <= cell_ptr_inc;  -- >
        when X"3C"  => instruction <= cell_ptr_dec;  -- <
        when X"2B"  => instruction <= cell_data_inc; -- +
        when X"2D"  => instruction <= cell_data_dec; -- -
        when X"5B"  => instruction <= while_start;   -- [
        when X"5D"  => instruction <= while_end;     -- ]
        when X"2E"  => instruction <= print;         -- .
        when X"2C"  => instruction <= get;           -- ,
        when X"24"  => instruction <= store;         -- $
        when X"21"  => instruction <= load;          -- !
        when X"00"  => instruction <= halt;          -- null
        when others => instruction <= nop;           -- other => nop
      end case;
    end process;

  mx1: process(CLK, sel1, mx2_out, pc_out)
    begin
      case sel1 is
        when '0' => DATA_ADDR <= pc_out;
        when '1' => DATA_ADDR <= mx2_out;
        when others =>
      end case;
    end process;

  mx2: process(CLK, sel2, ptr_out)
    begin
      case sel2 is
        when '0' => mx2_out <= ptr_out;
        when '1' => mx2_out <= "1000000000000";
        when others =>
      end case;
    end process;

  mx3: process(CLK, sel3, IN_DATA, DATA_RDATA)
    begin
      case sel3 is
        when "00" => DATA_WDATA <= IN_DATA;
        when "01" => DATA_WDATA <= DATA_RDATA + 1;
        when "10" => DATA_WDATA <= DATA_RDATA - 1;
        when "11" => DATA_WDATA <= DATA_RDATA;
        when others =>
      end case;
    end process;
  
  fsm_prev_state: process(RESET, CLK, EN, next_state)
    begin
      if (RESET = '1') then
        prev_state <= state_idle;
      elsif (rising_edge(CLK)) then
        if (EN = '1') then
          prev_state <= next_state;
        end if;
      end if;
    end process;

  fsm_next_state: process(RESET, CLK, EN, IN_VLD, OUT_BUSY, next_state, prev_state, instruction, sel1, sel2, sel3) -- cnt_out
    begin

      DATA_EN   <= '0';
      DATA_RDWR <= '0';
      IN_REQ    <= '0';
      OUT_WE    <= '0';

      pc_inc  <= '0';
      pc_dec  <= '0';
      ptr_inc <= '0';
      ptr_dec <= '0';
      cnt_inc <= '0';
      cnt_dec <= '0';
      
      case prev_state is
      
        when state_idle =>
          next_state <= state_fetch;
        
        when state_fetch =>
          next_state <= state_decode;

          DATA_EN <= '1';

          sel1 <= '0';
          sel2 <= '0';
          sel3 <= "11";
          
        when state_data_inc =>     -- +
          next_state <= state_data_inc_next;

          DATA_EN <= '1'; 

          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "11";

        when state_data_inc_next =>
          next_state <= state_fetch;

          DATA_EN   <= '1';
          DATA_RDWR <= '1';
          
          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "01";
          
          pc_inc <= '1';

        when state_data_dec =>     -- -
          next_state <= state_data_dec_next;

          DATA_EN <= '1'; 

          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "11";

        when state_data_dec_next =>
          next_state <= state_fetch;

          DATA_EN   <= '1';
          DATA_RDWR <= '1';
          
          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "10";
          
          pc_inc <= '1';

        when state_ptr_inc =>      -- >
          next_state <= state_fetch;
          ptr_inc    <= '1';
          pc_inc     <= '1';

        when state_ptr_dec =>      -- <
          next_state <= state_fetch;
          ptr_dec    <= '1';
          pc_inc     <= '1';

        when state_while1_start => -- [
          next_state <= state_while2_start;

          DATA_EN   <= '1';
          DATA_RDWR <= '0';

          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "11";

          pc_inc <= '1';

        when state_while2_start =>

          if (DATA_RDATA = "00000000") then
            next_state <= state_while3_start;
            cnt_inc <= '1';
          else
            next_state <= state_fetch;
          end if;

        when state_while3_start =>
          next_state <= state_while4_start;

          DATA_EN <= '1';

          sel1 <= '0';
          sel2 <= '0';
          sel3 <= "11";

        when state_while4_start =>
          next_state <= state_while5_start;

          pc_inc <= '1';
          
          if (instruction = while_start) then
            cnt_inc <= '1';
          elsif (instruction = while_end) then
            cnt_dec <= '1';
          end if;

        when state_while5_start =>
        
          if (cnt_out = "00000000") then
            next_state <= state_fetch;
          else
            next_state <= state_while3_start;
          end if;

        when state_while1_end =>   -- ]
          next_state <= state_while2_end;

          DATA_EN   <= '1';
          DATA_RDWR <= '0';

          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "11";

        when state_while2_end =>

          if (DATA_RDATA = "00000000") then
            next_state <= state_fetch;
            pc_inc     <= '1';
          else
            next_state <= state_while3_end;
            pc_dec  <= '1';
            cnt_inc <= '1';
          end if;
        
        when state_while3_end =>
          next_state <= state_while4_end;
          
          DATA_EN <= '1';
          
          sel1 <= '0';
          sel2 <= '0';
          sel3 <= "11";

        when state_while4_end =>
          
          next_state <= state_while5_end;
          
          if (instruction = while_start) then
            cnt_dec <= '1';
          elsif (instruction = while_end) then
            cnt_inc <= '1';
          end if;

        when state_while5_end =>

          if (cnt_out = "00000000") then
            next_state <= state_fetch;
            pc_inc <= '1';
          else
            next_state <= state_while3_end;
            pc_dec <= '1';
          end if;

        when state_print =>        -- .

          if (OUT_BUSY = '0') then
            next_state <= state_print_next;

            DATA_EN   <= '1';
            DATA_RDWR <= '0';

            sel1 <= '1';
            sel2 <= '0';
            sel3 <= "11";
          else
            next_state <= state_print;
          end if;

        when state_print_next =>
          next_state <= state_fetch;

          OUT_WE   <= '1';
          OUT_DATA <= DATA_RDATA;

          pc_inc <= '1';

        when state_get =>
          IN_REQ <= '1';
          if (IN_VLD = '1') then
            next_state <= state_fetch;
            DATA_EN <= '1';
            DATA_RDWR <= '1';
            sel1 <= '1';
            sel2 <= '0';
            sel3 <= "00";
            pc_inc <= '1';
          else
            next_state <= state_get;
          end if;

        when state_store =>         -- $
          next_state <= state_store_next;
            
          DATA_EN   <= '1';
          DATA_RDWR <= '0';
          
          sel1 <= '1';
          sel2 <= '0';  
      
        when state_store_next =>
          next_state <= state_fetch;
          
          DATA_EN   <= '1';
          DATA_RDWR <= '1';

          sel1 <= '1';
          sel2 <= '1';
          sel3 <= "11";  

          pc_inc <= '1';

        when state_load =>         -- !
          next_state <= state_load_next;
          
          DATA_EN   <= '1';
          DATA_RDWR <= '0';
          
          sel1 <= '1';
          sel2 <= '1';  
        
        when state_load_next =>
          next_state <= state_fetch;
          
          DATA_EN   <= '1';
          DATA_RDWR <= '1';

          sel1 <= '1';
          sel2 <= '0';
          sel3 <= "11";  

          pc_inc <= '1';

        when state_halt =>
          next_state <= state_halt;
        
        when state_nop =>
          next_state <= state_fetch;
          pc_inc     <= '1';
        
        when state_decode =>
          case instruction is

            when cell_data_inc =>
              next_state <= state_data_inc;
            
            when cell_data_dec =>
              next_state <= state_data_dec;

            when cell_ptr_inc =>
              next_state <= state_ptr_inc;

            when cell_ptr_dec =>
              next_state <= state_ptr_dec;

            when while_start =>
              next_state <= state_while1_start;
              
            when while_end =>
              next_state <= state_while1_end;

            when get =>
              next_state <= state_get;

            when print =>
              next_state <= state_print;

            when store =>
              next_state <= state_store;

            when load =>
              next_state <= state_load;

            when halt =>
              next_state <= state_halt;

            when others =>
              next_state <= state_nop;
          
          end case ;

        when others =>

      end case ;

    end process;

end behavioral;
 
