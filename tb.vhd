library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all; -- Libreria fondamentale per leggere/scrivere file .txt

library work;
use work.my_pkg.all; -- Carica il tuo package per il memory_array

entity tb_Systolic_FIR is
end entity tb_Systolic_FIR;

architecture Sim of tb_Systolic_FIR is

    -- Parametri
    constant DW   : integer := 16;
    constant ACCW : integer := 48;
    constant TAPS : integer := 17; -- Ricordati di allinearlo ai taps del Python!

    -- Segnali
    signal clk_i    : std_logic := '0';
    signal rst_i    : std_logic := '1';
    signal data_s_i : std_logic_vector(DW-1 downto 0) := (others => '0');
    signal coeff_i  : memory_array(0 to TAPS-1)(DW-1 downto 0) := (others => (others => '0'));
    signal fir_s_o  : std_logic_vector(ACCW-1 downto 0);

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz
    
    -- Segnale per fermare il clock a fine simulazione
    signal sim_done : boolean := false; 

begin

    -- Istanziazione del DUT (Direct Entity Instantiation, molto più pulita)
    dut: entity work.Systolic_FIR
        generic map (
            DW   => DW,
            ACCW => ACCW,
            TAPS => TAPS
        )
        port map (
            clk_i    => clk_i,
            rst_i    => rst_i,
            data_s_i => data_s_i,
            coeff_i  => coeff_i,
            fir_s_o  => fir_s_o
        );

    -- Generazione del Clock
    clk_proc: process
    begin
        while not sim_done loop
            clk_i <= '1';
            wait for CLK_PERIOD / 2;
            clk_i <= '0';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Processo di Stimolo (Lettura Coefficienti e Campioni)
    stimulus_proc: process
        file fd_coeff     : text open read_mode is "C:/Users/Riccardo/Documents/Progetti_personali/Array_Sistolico/coeffs.txt";
        file fd_samples   : text open read_mode is "C:/Users/Riccardo/Documents/Progetti_personali/Array_Sistolico/samples.txt";
        variable v_line   : line;
        variable v_int    : integer;
    begin
        -- 1. Inizializzazione (Reset)
        rst_i <= '1';
        
        -- 2. Lettura dei Coefficienti (Pesi)
        for i in 0 to TAPS-1 loop
            if not endfile(fd_coeff) then
                readline(fd_coeff, v_line);
                read(v_line, v_int);
                -- Converte l'intero letto da file in std_logic_vector
                coeff_i(i) <= std_logic_vector(to_signed(v_int, DW));
            end if;
        end loop;
        report "Coefficienti caricati con successo nell'array 2D.";

        -- Rilascio del reset
        wait for CLK_PERIOD * 2;
        rst_i <= '0';
        wait for CLK_PERIOD;

        -- 3. Iniezione dei campioni d'ingresso
        while not endfile(fd_samples) loop
            -- Iniettiamo sul fronte di discesa per evitare colli di bottiglia Setup/Hold in simulazione
            wait until falling_edge(clk_i); 
            
            readline(fd_samples, v_line);
            read(v_line, v_int);
            data_s_i <= std_logic_vector(to_signed(v_int, DW));
        end loop;

        -- Svuotamento della pipeline (Latenza dell'array sistolico)
        wait for CLK_PERIOD * (TAPS + 5);
        
        report "Simulazione completata con successo.";
        sim_done <= true; -- Ferma il clock e chiude la simulazione
        wait;
    end process;

    -- Processo di Monitoraggio (Scrittura Risultati)
    monitor_proc: process
        file fd_out     : text open write_mode is "C:/Users/Riccardo/Documents/Progetti_personali/Array_Sistolico/output.txt";
        variable v_line : line;
        variable v_out_int : integer;
    begin
        wait until rising_edge(clk_i);
        
        if rst_i = '0' and not sim_done then
            -- ATTENZIONE: Il tipo 'integer' in VHDL arriva a massimo 32 bit.
            -- Poiché il nostro accumulatore è a 48 bit, estraiamo i 32 bit più bassi (troncamento).
            -- Per segnali audio standard e 31 Taps, il segnale non sborderà mai oltre i 32 bit.
            v_out_int := to_integer(signed(fir_s_o(31 downto 0)));
            
            write(v_line, v_out_int);
            writeline(fd_out, v_line);
        end if;
    end process;

end architecture Sim;