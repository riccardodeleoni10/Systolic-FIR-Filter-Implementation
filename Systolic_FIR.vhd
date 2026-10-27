library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.my_pkg.all;

entity Systolic_FIR is
  generic (
     DW     : integer := 16; 
     ACCW   : integer := 48;
     TAPS   : integer := 17
  );
  port (
     clk_i      : in std_logic;
     rst_i      : in std_logic;
     data_s_i   : in std_logic_vector(DW-1 downto 0);              -- data stram input (add:AXI-Stream Interface)
     coeff_i   : in memory_array (0 to TAPS-1)(DW -1 downto 0);    -- filter coefficient (will be hardcoded or set by Axi-Lite Interface)
     fir_s_o    : out std_logic_vector(ACCW-1 downto 0) 
   ); 
end entity Systolic_FIR;

architecture Generative of Systolic_FIR is

component MAC is 
    generic (
        DW   : integer;  
        ACCW : integer
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
end component;

type mac_prop_t  is array(0 to TAPS) of std_logic_vector(ACCW-1 downto 0);
type data_prop_t is array(0 to TAPS-1) of std_logic_vector(DW-1 downto 0); 

signal mac_prop_s  : mac_prop_t;
signal data_prop_s : data_prop_t;

begin

mac_prop_s(0)  <= (others => '0');
data_prop_s(0) <= data_s_i;

systolic_array_generation: for i in 0 to (TAPS - 1) generate 

    internal_macs: if i < (TAPS - 1) generate
        mac_inst: MAC 
        generic map(
            DW => DW, 
            ACCW => ACCW)
        port map (
            clk_i    => clk_i,
            rst_i    => rst_i,
            data_i   => data_prop_s(i),
            y_prev_i => mac_prop_s(i),
            coeff_i  => coeff_i(i),
            data_o   => data_prop_s(i+1), 
            y_o      => mac_prop_s(i+1)
        );
    end generate internal_macs;
    last_mac: if i = (TAPS - 1) generate
        mac_inst: MAC 
        generic map(
            DW => DW, 
            ACCW => ACCW
            )
        port map (
            clk_i    => clk_i,
            rst_i    => rst_i,
            data_i   => data_prop_s(i),
            y_prev_i => mac_prop_s(i),
            coeff_i  => coeff_i(i),
            data_o   => open,             
            y_o      => mac_prop_s(i+1)   
        );
    end generate last_mac;
end generate systolic_array_generation;
 fir_s_o <= mac_prop_s(TAPS);

end architecture Generative;