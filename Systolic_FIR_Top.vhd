----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 31.10.2026 09:10:15
-- Design Name: 
-- Module Name: Systolic_FIR_Top - Behavioral
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
use ieee.std_logic_unsigned.all;
use std.textio.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Systolic_FIR_Top is
    generic (
	    C_DW                   : integer := 16;
        C_AW                   : integer := 48;
        c_TAPS                 : integer := 6;
        COEFF_FILE             : string;
	    USE_AXI_INTERFACE      : boolean := false;
        -- if USE_AXI_INTERFACE is "True", the IP Systolic FIR will be wrapped in 
        -- AXI Lite, to dynamically configure registers. Otherwise, it will have just AXI Stream interface
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer := integer(ceil(log2(real(C_TAPS)))) + integer(log2(real(32/8)))
	);
	port (
	    -- Axi stream interface
	  s_rst_i         : in std_logic ;
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
      m_axis_tlast  : OUT STD_LOGIC;
    	-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
		
	);
end Systolic_FIR_Top;

architecture Behavioral of Systolic_FIR_Top is
component AXI_Systolic_FIR_v1_0 is
	generic (
	    C_DW                   : integer := 16;
        C_AW                   : integer := 48;
        c_TAPS                 : integer := 6;
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer := integer(ceil(log2(real(C_TAPS)))) + integer(log2(real(32/8)))
	);
	port (
	    data_in         : in std_logic_vector (C_DW -1 downto 0);
        data_out        : out std_logic_vector  (C_AW -1 downto 0);
    	-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end component AXI_Systolic_FIR_v1_0;
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

 impure function init_Coeff(init_File: string) return std_logic_vector is
        file     coeff_File   : text open read_mode is init_File;
        variable file_Line    : line;
        variable temp_bv      : bit_vector(C_DW-1 downto 0);
        variable temp_slv     : std_logic_vector(C_DW-1 downto 0);
        -- Inizializziamo a zero l'intero vettore di uscita
        variable result_rom   : std_logic_vector((C_TAPS*C_DW)-1 downto 0) := (others => '0');
        variable line_count   : integer := 0;
    begin
        -- Se il nome del file è vuoto (es. in simulazione prima di settarlo), restituisci zero
        if init_File = "" then
            report "Nessun file coefficienti specificato (COEFF_FILE vuoto). Inizializzazione a 0." severity warning;
            return result_rom;
        end if;

        -- Leggi il file riga per riga fino a C_TAPS
        for i in 0 to C_TAPS-1 loop
            if not endfile(coeff_File) then
                readline(coeff_File, file_Line);
                read(file_Line, temp_bv);
                temp_slv := to_stdlogicvector(temp_bv);
                
                -- Concatena o "impacchetta" il singolo coefficiente letto nel vettore lungo.
                -- Uguale alla logica di packing che abbiamo usato nell'AXI.
                result_rom(((i + 1) * C_DW) - 1 downto (i * C_DW)) := temp_slv;
                line_count := line_count + 1;
            else
                -- ALERTA 1: Il file ha MENO righe dei TAPS richiesti.
                report "CRITICO: Il file dei coefficienti contiene meno righe (" & integer'image(line_count) & 
                       ") rispetto al numero di TAPS richiesto (" & integer'image(C_TAPS) & ")." severity error;
                exit; -- Esce dal ciclo, i restanti bit rimarranno a '0'
            end if;
        end loop;
        
        -- ALERTA 2: Il file ha PIU' righe del necessario.
        if not endfile(coeff_File) then
             report "ATTENZIONE: Il file dei coefficienti ha piu' righe del numero di TAPS (" & integer'image(C_TAPS) & 
                    "). Le righe in eccesso verranno ignorate." severity warning;
        end if;

        return result_rom;
    end function;

signal coeff_from_file : std_logic_vector ((C_TAPS * C_DW)-1 downto 0) := (init_coeff(coeff_file));
begin
AXI_Systolic_Fir_Generate: if USE_AXI_INTERFACE  = true generate
    AXI_Systolic_FIR_inst: AXI_Systolic_FIR_v1_0 
        generic map(
            C_DW                  => C_DW,
            C_AW                  => C_AW,
            c_TAPS                => C_TAPS,
            C_S00_AXI_DATA_WIDTH  => C_S00_AXI_DATA_WIDTH,
            C_S00_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
        )
        port map(
            data_in         => data_in,
            data_out        => data_out,
            s00_axi_aclk	=> s00_axi_aclk,
            s00_axi_aresetn	 => s00_axi_aresetn,
            s00_axi_awaddr	=> s00_axi_awaddr,
            s00_axi_awprot	=> s00_axi_awprot,
            s00_axi_awvalid	=> s00_axi_awvalid,
            s00_axi_awready	 => s00_axi_awready,
            s00_axi_wdata	=> s00_axi_wdata,
            s00_axi_wstrb	=> s00_axi_wstrb,
            s00_axi_wvalid	=> s00_axi_wvalid,
            s00_axi_wready	=> s00_axi_wready,
            s00_axi_bresp	=> s00_axi_bresp,
            s00_axi_bvalid	=> s00_axi_bvalid,
		    s00_axi_bready	=> s00_axi_bready,
            s00_axi_araddr	=> s00_axi_araddr,
            s00_axi_arprot	=> s00_axi_arprot,
            s00_axi_arvalid	=> s00_axi_arvalid,
            s00_axi_arready	=> s00_axi_arready,
            s00_axi_rdata	=> s00_axi_rdata,
            s00_axi_rresp	=> s00_axi_rresp,
            s00_axi_rvalid	=> s00_axi_rvalid,
            s00_axi_rready	=> s00_axi_rready
        );
    
end generate;
Systolic_FIR_generate: if USE_AXI_INTERFACE = false generate
    Raw_Systolic_FIR_inst: Systolic_FIR
            generic map(
                DW   => C_DW,
                ACCW => C_AW,
                TAPS => C_TAPS
            )
            port map(
                clk_i    => s00_axi_aclk,          
                rst_i    => not(s00_axi_aresetn),  
                data_s_i => data_in,
                coeff_i  => coeff_from_file,              
                fir_s_o  => data_out
            );
        s00_axi_awready <= '0';
        s00_axi_wready  <= '0';
        s00_axi_bresp   <= "00";
        s00_axi_bvalid  <= '0';
        s00_axi_arready <= '0';
        s00_axi_rdata   <= (others => '0');
        s00_axi_rresp   <= "00";
        s00_axi_rvalid  <= '0';
       
end generate ;
end Behavioral;
