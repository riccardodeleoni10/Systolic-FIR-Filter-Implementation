library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AXI_Systolic_FIR_v1_0_S00_AXI is
	generic (
		-- Users to add parameters here
		C_DW                    : integer := 16;
		C_AW                    : integer := 48;
		C_TAPS                  : integer := 6;
		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer := 32;
		-- Width of S_AXI address bus calcolato automaticamente
		C_S_AXI_ADDR_WIDTH	: integer := 8
	);
	port (
		-- Users to add ports here
        data_in: in std_logic_vector (C_DW -1 downto 0);
        data_out: out std_logic_vector (C_AW -1 downto 0);
        coeff_port_out: out std_logic_vector ((C_DW*C_TAPS)-1 downto 0); 
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Global Clock Signal
		S_AXI_ACLK	: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		S_AXI_ARESETN	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. 
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		-- Write address valid. 
		S_AXI_AWVALID	: in std_logic;
		-- Write address ready. 
		S_AXI_AWREADY	: out std_logic;
		-- Write data (issued by master, acceped by Slave) 
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. 
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		-- Write valid. 
		S_AXI_WVALID	: in std_logic;
		-- Write ready. 
		S_AXI_WREADY	: out std_logic;
		-- Write response. 
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		-- Write response valid. 
		S_AXI_BVALID	: out std_logic;
		-- Response ready. 
		S_AXI_BREADY	: in std_logic;
		-- Read address (issued by master, acceped by Slave)
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		-- Protection type. 
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		-- Read address valid. 
		S_AXI_ARVALID	: in std_logic;
		-- Read address ready. 
		S_AXI_ARREADY	: out std_logic;
		-- Read data (issued by slave)
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. 
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		-- Read valid. 
		S_AXI_RVALID	: out std_logic;
		-- Read ready. 
		S_AXI_RREADY	: in std_logic
	);
end AXI_Systolic_FIR_v1_0_S00_AXI;

architecture arch_imp of AXI_Systolic_FIR_v1_0_S00_AXI is
    -- Fir Component 
    component Systolic_FIR is
      generic (
          DW   : integer ; 
          ACCW : integer ;
          TAPS : integer 
      );
      port (
          clk_i      : in std_logic;
          rst_i      : in std_logic;
          data_s_i   : in std_logic_vector(DW-1 downto 0);                
          coeff_i    : in std_logic_vector((TAPS * DW)-1 downto 0);      
          fir_s_o    : out std_logic_vector(ACCW-1 downto 0) 
       ); 
    end component ;

	-- AXI4LITE signals
	signal axi_awaddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awready	: std_logic;
	signal axi_wready	: std_logic;
	signal axi_bresp	: std_logic_vector(1 downto 0);
	signal axi_bvalid	: std_logic;
	signal axi_araddr	: std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arready	: std_logic;
	signal axi_rdata	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal axi_rresp	: std_logic_vector(1 downto 0);
	signal axi_rvalid	: std_logic;

	-- Example-specific design signals
	constant ADDR_LSB  : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
	constant OPT_MEM_ADDR_BITS : integer := 1;
	
	------------------------------------------------
	---- Signals for user logic register space example
	--------------------------------------------------
	type slv_reg_t is array (0 to C_TAPS-1) of std_logic_vector (C_S_AXI_DATA_WIDTH-1 downto 0);
	signal coeff_slv_regs: slv_reg_t := (others => (others => '0')); -- Inizializzazione utile in simulazione
	signal packed_coeff: std_logic_vector ((C_TAPS*C_DW)-1 downto 0);
	
	-- Rimossi slv_reg0, 1, 2, 3 perche' non più usati
	
	signal slv_reg_rden	: std_logic;
	signal slv_reg_wren	: std_logic;
	signal reg_data_out	: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	signal byte_index	: integer;
	signal aw_en	: std_logic;

begin
	-- I/O Connections assignments

	S_AXI_AWREADY	<= axi_awready;
	S_AXI_WREADY	<= axi_wready;
	S_AXI_BRESP	<= axi_bresp;
	S_AXI_BVALID	<= axi_bvalid;
	S_AXI_ARREADY	<= axi_arready;
	S_AXI_RDATA	<= axi_rdata;
	S_AXI_RRESP	<= axi_rresp;
	S_AXI_RVALID	<= axi_rvalid;

	-- Implement axi_awready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awready <= '0';
	      aw_en <= '1';
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	           axi_awready <= '1';
	           aw_en <= '0';
	        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
	           aw_en <= '1';
	           axi_awready <= '0';
	      else
	        axi_awready <= '0';
	      end if;
	    end if;
	  end if;
	end process;

	-- Implement axi_awaddr latching
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_awaddr <= (others => '0');
	    else
	      if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
	        axi_awaddr <= S_AXI_AWADDR;
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_wready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_wready <= '0';
	    else
	      if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
	          axi_wready <= '1';
	      else
	        axi_wready <= '0';
	      end if;
	    end if;
	  end if;
	end process; 

	-- Implement memory mapped register select and write logic generation
	slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

	process (S_AXI_ACLK)
	  variable loc_addr : integer;
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      -- Reset dinamico di tutti i registri
	      for i in 0 to C_TAPS-1 loop
	        coeff_slv_regs(i) <= (others => '0');
	      end loop;
	    else
	      -- Calcolo dell'indice dell'array partendo dall'indirizzo AXI
	      loc_addr := to_integer(unsigned(axi_awaddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB)));
	      
	      if (slv_reg_wren = '1') then
	        -- Controlla che l'indirizzo sia nei limiti dei TAPS istanziati
	        if (loc_addr < C_TAPS) then
	          for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
	            if ( S_AXI_WSTRB(byte_index) = '1' ) then
	              -- Scrittura byte per byte
	              coeff_slv_regs(loc_addr)(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
	            end if;
	          end loop;
	        end if;
	      end if;
	    end if;
	  end if;                   
	end process;

	-- Implement write response logic generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_bvalid  <= '0';
	      axi_bresp   <= "00";
	    else
	      if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
	        axi_bvalid <= '1';
	        axi_bresp  <= "00"; 
	      elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then   
	        axi_bvalid <= '0';                                 
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arready generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then 
	    if S_AXI_ARESETN = '0' then
	      axi_arready <= '0';
	      axi_araddr  <= (others => '1');
	    else
	      if (axi_arready = '0' and S_AXI_ARVALID = '1') then
	        axi_arready <= '1';
	        axi_araddr  <= S_AXI_ARADDR;            
	      else
	        axi_arready <= '0';
	      end if;
	    end if;
	  end if;                   
	end process; 

	-- Implement axi_arvalid generation
	process (S_AXI_ACLK)
	begin
	  if rising_edge(S_AXI_ACLK) then
	    if S_AXI_ARESETN = '0' then
	      axi_rvalid <= '0';
	      axi_rresp  <= "00";
	    else
	      if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
	        axi_rvalid <= '1';
	        axi_rresp  <= "00"; 
	      elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
	        axi_rvalid <= '0';
	      end if;            
	    end if;
	  end if;
	end process;

	-- Implement memory mapped register select and read logic generation
    slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

	process (coeff_slv_regs, axi_araddr, S_AXI_ARESETN, slv_reg_rden)
	  variable loc_addr : integer;
	begin
	    -- Calcolo dell'indice dell'array
	    loc_addr := to_integer(unsigned(axi_araddr(C_S_AXI_ADDR_WIDTH-1 downto ADDR_LSB)));
	    
	    -- Se l'indirizzo rientra nei taps definiti, leggi il registro corrispondente, altrimenti 0
	    if (loc_addr < C_TAPS) then
	        reg_data_out <= coeff_slv_regs(loc_addr);
	    else
	        reg_data_out <= (others => '0');
	    end if;
	end process;
	
	-- Output register or memory read data
	process( S_AXI_ACLK ) is
	begin
	  if (rising_edge (S_AXI_ACLK)) then
	    if ( S_AXI_ARESETN = '0' ) then
	      axi_rdata  <= (others => '0');
	    else
	      if (slv_reg_rden = '1') then
	          axi_rdata <= reg_data_out;     -- register read data
	      end if;   
	    end if;
	  end if;
	end process;

    -- Add user logic here
    -- Risolto errore di width mismatch: preleva solo i bit da C_DW-1 a 0
packing_coeffs: for i in 0 to (C_TAPS - 1) generate
     packed_coeff(((i + 1) * C_DW) - 1 downto (i * C_DW)) <= coeff_slv_regs(i)(C_DW-1 downto 0);
end generate packing_coeffs;

coeff_port_out <= packed_coeff;

systolic_fir_inst: Systolic_FIR
  generic map (
      DW   => C_DW,
      ACCW => C_AW,
      TAPS => C_TAPS
  ) 
  port map (
      clk_i    => S_AXI_ACLK, 
      rst_i   => not(S_AXI_ARESETN),   
      data_s_i => data_in,                  
      coeff_i  => packed_coeff,      
      fir_s_o  => data_out  
  );
-- User logic ends

end arch_imp;
