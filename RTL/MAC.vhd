library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MAC is
  generic (
     DW     : integer;  
     ACCW   : integer
  );
  port (
     clk_i    : in std_logic;
     rst_i    : in std_logic;
     data_i   : in std_logic_vector(DW-1 downto 0);
     y_prev_i : in std_logic_vector(ACCW-1 downto 0);
     coeff_i  : in std_logic_vector(DW-1 downto 0);
     data_o   : out std_logic_vector(DW-1 downto 0);
     y_o      : out std_logic_vector(ACCW-1 downto 0)
   ); 
end entity MAC;

architecture RTL of MAC is
    signal coeff_s       : std_logic_vector(DW-1 downto 0);
    signal data_s    : std_logic_vector(DW-1 downto 0);
    signal data_s2   : std_logic_vector(DW-1 downto 0);
    signal mul_reg   : signed(ACCW-1 downto 0);
    attribute use_dsp : string;
    -- The attributes below will force the sinthetizer to use DSP to compute MAC operation
    attribute USE_DSP of y_o     : signal is "yes"; 
    attribute USE_DSP of mul_reg : signal is "yes";
begin
-- Weight Loading register 
w_register_proc: process(clk_i)
begin 
    if rising_edge(clk_i) then 
        if rst_i = '1' then
            coeff_s <= (others => '0'); 
        else 
            coeff_s <= coeff_i; 
        end if;
    end if;
end process;

-- Propagation of input data, 2 systolic delays
data_forwarding_proc: process(clk_i)
begin 
    if rising_edge(clk_i) then 
        if rst_i = '1' then 
            data_s  <= (others => '0');
            data_s2 <= (others => '0');
        else 
            data_s  <= data_i;   
            data_s2 <= data_s;   
        end if;
    end if;
end process;
data_o <= data_s2; 

mac_pipeline_proc: process(clk_i)
begin 
    if rising_edge(clk_i) then
        if rst_i = '1' then
            mul_reg <= (others => '0');
            y_o     <= (others => '0');
        else
            -- 1. Stadio Moltiplicatore (M-Register)
            mul_reg <= resize(signed(coeff_s) * signed(data_s), ACCW);
            
            -- 2. Stadio Sommatore (P-Register dell'immagine)
            y_o <= std_logic_vector(signed(y_prev_i) + mul_reg);
        end if;
    end if;
end process;

end architecture RTL;
