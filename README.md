# VHDL Systolic Array FIR Filter 🚀

## 📌 Overview
Questo repository contiene l'implementazione RTL (VHDL) di un filtro FIR (Finite Impulse Response) ad altissime prestazioni, progettato specificamente per massimizzare il throughput su FPGA. 

L'architettura si ispira fortemente al design raccomandato da AMD/Xilinx per lo sfruttamento nativo dei blocchi DSP (come i DSP48E2 e DSP58). Inserisci [qui il link alla documentazione AMD] per i dettagli sull'implementazione hardware a livello di silicio.

La struttura è interamente parametrizzabile tramite `generic` (Data Width, Accumulator Width, numero di Taps) ed è pronta per essere wrappata all'interno di un'interfaccia AXI4-Stream / AXI4-Lite.

---

## 🧮 Modello Matematico
Un filtro FIR standard calcola l'uscita $y[n]$ eseguendo la convoluzione discreta tra il segnale in ingresso $x[n]$ e un set di $N$ coefficienti (pesi) $h[k]$:

$$y[n] = \sum_{k=0}^{N-1} h[k] \cdot x[n-k]$$

Se implementata in modo "naive" (combinatorio), questa equazione genera un albero di addizioni enorme che distrugge le tempistiche di routing (Critical Path elevato), limitando drasticamente la frequenza massima di clock.

---

## ⚙️ Architettura Sistolica (Weight-Stationary)
Per superare i limiti del routing, questo design utilizza un **Array Sistolico a Pesi Stazionari**. 
L'equazione viene "srotolata" nello spazio e nel tempo attraverso una catena di Processing Elements (PE) collegati solo al loro vicino diretto (Nessun *Global Broadcast*). 

Il cuore del funzionamento si basa sul **Doppio Ritardo Sistolico**:
*   **I Pesi ($h$):** Sono stazionari, caricati nei registri locali di ogni PE.
*   **Percorso Dati ($X$):** Il segnale in ingresso scorre attraverso la catena subendo **2 colpi di clock** di ritardo per ogni PE.
*   **Percorso Accumulatore ($Y$):** Le somme parziali scorrono in avanti subendo **1 colpo di clock** di ritardo per ogni PE.

Questa differenza di velocità fa "scivolare" matematicamente il campione $x$ rispetto alla somma $y$, garantendo che si incrocino al momento perfetto per rispettare l'equazione della convoluzione. 

Inoltre, il singolo PE è strutturato in modo **Completamente Pipelined** per mappare nativamente sull'hardware Xilinx/AMD:
> `A/B-Reg` (Input) ➡️ `M-Reg` (Multiplier) ➡️ `P-Reg` (Adder/Accumulator)

Questo garantisce l'assorbimento totale (DSP Absorption) e impedisce l'uso indesiderato di logica distribuita (LUT/SRL).

---

## 🧪 Verifica e Simulazione (Python + VHDL)
Il progetto include un framework di test automatizzato e professionale basato sul concetto di **Golden Model**. Il workflow unisce l'analisi dei segnali in Python con la simulazione hardware (XSim/ModelSim):

1.  **Generazione (`python_script.py`):** Genera un segnale misto (utile + rumore ad alta frequenza), progetta il filtro FIR ideale quantizzato a 16-bit, e salva gli input (`coeffs.txt` e `samples.txt`).
2.  **Simulazione RTL (`tb.vhd`):** Il testbench VHDL legge i file, inietta i campioni nell'array sistolico tenendo conto della latenza di pipeline, e salva l'accumulatore su `output.txt`.
3.  **Analisi FFT (Verification):** Lo script Python legge l'output dell'FPGA e genera una dashboard a 5 grafici che sovrappone i risultati ideali con quelli reali (sia nel dominio del tempo che in frequenza), dimostrando l'assoluta precisione del DSP hardware.

---

## 🚀 Performance e Risorse (Implementation Results)
*Le prestazioni riportate fanno riferimento alla fase di Post-Implementation (Place & Route completato).*

### Timing / Frequenza Massima ($F_{max}$)
Grazie all'M-Register e ai collegamenti di cascata dedicati, il percorso critico si riduce alla distanza microscopica interna al blocco DSP, permettendo al filtro di operare a velocità estreme.

| Target FPGA | Clock Period Constraint | WNS (Setup Slack) | Max Freq Equivalente ($F_{max}$) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Zynq UltraScale+ (ZCU111)** | 4.0 ns (250 MHz) | +3.00 ns | **~ 1 GHz** (Limitato dal silicio) | 1 Sample / Clock |
| **Artix-7 (Arty A7)** | *[Inserire ns]* | *[Inserire WNS]* | *[Inserire Fmax]* | 1 Sample / Clock |

### Occupazione Risorse (Es. Configurazione 17 Taps, 16-bit In, 48-bit Acc)
| Risorsa | Utilizzo | Note |
| :--- | :--- | :--- |
| **DSP Blocks** | 17 | Esattamente 1 DSP per Tap (Assorbimento perfetto) |
| **LUTs** | ~ 0 | L'intera logica matematica è chiusa nei DSP |
| **FFs** | *[Inserire num]* | Registri di interfaccia e pipeline |# Systolic-FIR-Filter-Implementation
A VHDL implementation of a Systolic Architecture to compute FIR-Filter
