----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.11.2026 02:20:10
-- Design Name: 
-- Module Name: AXI_Stream_Systolic_FIR - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AXI_Stream_Systolic_FIR is
      generic (
        C_DW                   : integer := 16;
        C_AW                   : integer := 48;
        c_TAPS                 : integer := 6;
        T_LAST_TH              : integer := 1024;
        T_LAST_ACCW         : integer := integer(ceil(log2(real(T_LAST_TH))));
        COEFF_FILE             : string
      );
      Port (
      rst_i         : in std_logic ;
      coeff_port    : in std_logic_vector ((C_DW*C_TAPS)-1 downto 0); 
      -- Slave Stream Interface Port
      s_aclk        : IN STD_LOGIC;
      s_aresetn     : IN STD_LOGIC;
      s_axis_tvalid : IN STD_LOGIC;
      s_axis_tready : OUT STD_LOGIC;
      s_axis_tdata  : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
      s_axis_tlast  : IN STD_LOGIC;
      -- Master Stream Interface port
      m_aclk        : IN STD_LOGIC;
      m_axis_tvalid : OUT STD_LOGIC;
      m_axis_tready : IN STD_LOGIC;
      m_axis_tdata  : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_tlast  : OUT STD_LOGIC
      );
end AXI_Stream_Systolic_FIR;

architecture Behavioral of AXI_Stream_Systolic_FIR is
component Systolic_FIR is
  generic (
      DW   : integer := 16; 
      ACCW : integer := 48;
      TAPS : integer := 17
  );
  port (
      clk_i      : in std_logic;
      rst_i      : in std_logic;
      data_s_i   : in std_logic_vector(DW-1 downto 0);               
      coeff_i    : in std_logic_vector((TAPS * DW)-1 downto 0);      
      fir_s_o    : out std_logic_vector(ACCW-1 downto 0) 
   ); 
end component Systolic_FIR;

constant PIPELINE_DEPTH: integer := (C_TAPS-1 + 2 );
signal s_valid_shreg: std_logic_vector (PIPELINE_DEPTH -1 downto 0);
signal s_tlast_shreg: std_logic_vector (PIPELINE_DEPTH -1 downto 0);
signal t_last_acc   : std_logic_vector (T_LAST_ACCW -1 downto 0);
signal t_last_reg   : std_logic ;
begin
s_axis_tready <= '1';
shift_register_process:process(m_aclk)
begin
    if rising_edge (m_aclk) then 
        if rst_i = '1' then
            s_valid_shreg <= (others => '0');
            s_tlast_shreg <= (others => '0');
        else 
            for i in 0 to PIPELINE_DEPTH-2 loop
                s_valid_shreg(i+1) <= s_valid_shreg(i);
                s_tlast_shreg(i+1) <= s_tlast_shreg(i);
            end loop;
        end if;
    end if;  
end process;
s_valid_shreg(0) <= s_axis_tvalid;
m_axis_tvalid <= s_valid_shreg(PIPELINE_DEPTH -1);
s_tlast_shreg(0) <= s_axis_tlast;

t_last_generate: process(m_aclk)
begin 
    if rising_edge (m_aclk) then
        if rst_i = '1' then 
           t_last_acc <= (others => '0');
           t_last_reg <= '0';
        end if;
        if s_tlast_shreg(PIPELINE_DEPTH-1) = '1' or t_last_acc = std_logic_vector(to_unsigned(T_LAST_TH-1,T_LAST_ACCW)) then
            t_last_reg <= '1';
        elsif s_valid_shreg(PIPELINE_DEPTH -1) = '1' then 
            t_last_acc <= std_logic_vector(unsigned (t_last_acc)+1);
        else 
            t_last_reg <= '0';
        end if;   
    end if;
end process;

Systolic_fir_inst: Systolic_FIR 
    generic map (
     DW   => C_DW,
      ACCW  => C_AW,
      TAPS => C_TAPS  
    ) port map (
        clk_i      => m_aclk,
        rst_i      => rst_i,
        data_s_i   => s_axis_tdata(C_DW-1 downto 0),               
        coeff_i    => coeff_port,      
        fir_s_o    => m_axis_tdata(C_AW -1 downto 0)
    );
end Behavioral;
