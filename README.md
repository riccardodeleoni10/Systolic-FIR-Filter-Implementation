# VHDL Systolic Array FIR Filter 🚀

Filtro FIR ad alte prestazioni in VHDL basato su architettura ad array sistolico (Weight-Stationary) ottimizzata per DSP Xilinx/AMD. Include un ambiente di verifica automatizzato con Golden Model in Python per l'analisi spettrale (FFT).

---

## Indice
1. [Background Teorico: Array Sistolici e FIR in Hardware](#1-background-teorico-array-sistolici-e-fir-in-hardware)
2. [Architettura Hardware (RTL)](#2-architettura-hardware-rtl)
3. [Metodologia di Simulazione e Verifica](#3-metodologia-di-simulazione-e-verifica)
4. [Struttura del Repository](#4-struttura-del-repository)
5. [Sviluppi Futuri](#6-sviluppi-futuri)
---

## 1. Background Teorico: Array Sistolici e FIR in Hardware

### Cos'è un Array Sistolico?
Ispirato al battito cardiaco (sistole), un array sistolico è una rete di unità di calcolo (Processing Elements, PE) che "pompa" i dati in modo ritmico attraverso il chip. Invece di leggere e scrivere continuamente dalla memoria centrale, i dati passano da un PE all'altro, elaborando operazioni complesse in parallelo a ogni colpo di clock.

### Il "Routing Wall" e il Riutilizzo dei Dati
Un filtro FIR calcola l'uscita $y[n]$ eseguendo la convoluzione discreta tra il segnale in ingresso $x[n]$ e un set di $N$ coefficienti $h[k]$:

$$y[n] = \sum_{k=0}^{N-1} h[k] \cdot x[n-k]$$

Se implementata in modo combinatorio tradizionale, questa equazione genera un albero di addizioni enorme. Su FPGA, questo si traduce in lunghi percorsi di routing ("Routing Wall") che distruggono le tempistiche e limitano la frequenza massima ($F_{max}$). L'architettura sistolica risolve il problema garantendo che le connessioni avvengano **solo tra blocchi adiacenti**.

### Il Doppio Ritardo Sistolico (Giustificazione Matematica)
Per far sì che l'equazione del FIR sia matematicamente esatta in un'architettura pipelined distribuita (Weight-Stationary), l'incrocio tra i dati $X$ e le somme parziali $Y$ deve essere perfettamente fasato. Per ottenerlo, **i dati in ingresso subiscono 2 ritardi di clock per ogni nodo, mentre l'accumulatore 1 solo ritardo.**

La tabella seguente mostra l'andamento temporale (Wavefront Timing) per un filtro a 2 Tap calcolando $y[n] = h_0 \cdot x[n] + h_1 \cdot x[n-1]$:

| Clock | Ingresso ($X$) | PE 0 (Peso $h_0$) | Ritardo Extra $X$ | PE 1 (Peso $h_1$) | Uscita Sistema ($Y_{out}$) |
| :---: | :---: | :--- | :--- | :--- | :--- |
| **0** | $x[0]$ | Calcola: $y_0 = h_0 \cdot x[0]$ | Salva $x[0]$ (1° ritardo) | Inattivo | - |
| **1** | $x[1]$ | Calcola: $y_1 = h_0 \cdot x[1]$ <br> *Invia $y_0$ al PE1* | Salva $x[1]$ <br> *Invia $x[0]$ al PE1* (2° ritardo) | Inattivo (riceve $y_0$ ma non ha ancora $x$) | - |
| **2** | $x[2]$ | Calcola: $y_2 = h_0 \cdot x[2]$ <br> *Invia $y_1$ al PE1* | Salva $x[2]$ <br> *Invia $x[1]$ al PE1* | Riceve $y_1$ e $x[0]$. <br> Calcola: **$y_1 + h_1 \cdot x[0]$** | Esce $y[1]$ parziale |
| **3** | $x[3]$ | Calcola: $y_3 = h_0 \cdot x[3]$ <br> *Invia $y_2$ al PE1* | Salva $x[3]$ <br> *Invia $x[2]$ al PE1* | Riceve $y_2$ e $x[1]$. <br> Calcola: **$y_2 + h_1 \cdot x[1]$** | **Esce $y[1]$ completo!** <br> $(h_0 x[1] + h_1 x[0])$ |

Come si evince, al Clock 2 il PE1 riceve esattamente la somma parziale del campione $x[1]$ e il dato in ingresso $x[0]$, permettendo di calcolare correttamente il primo campione filtrato valido $y[1]$.

---

## 2. Architettura Hardware (RTL)

### Microarchitettura del Processing Element (`MAC.vhd`)
Il singolo PE è fortemente ispirato all'architettura dei blocchi **DSP48E2 / DSP58 di AMD/Xilinx**. Per mappare perfettamente l'hardware nativo e raggiungere frequenze elevatissime, il calcolo Multiply-Accumulate (MAC) è spezzato in una pipeline profonda.

> 🖼️ **[INSERIRE QUI IMMAGINE: dsp58_architecture.png]**
> *Didascalia: Schema a blocchi interno di uno slice DSP58 AMD/Xilinx. Notare i registri interposti tra moltiplicatore e sommatore.*

Il VHDL è scritto per inferire esattamente questi registri:
1. **A/B-Reg:** Stabilizzazione dell'ingresso (1° ritardo dei dati).
2. **M-Reg (Multiplier Register):** Registro intermedio per spezzare il percorso critico della moltiplicazione.
3. **P-Reg (Accumulator Register):** Registro finale che salva la somma con il blocco precedente (Ritardo dell'accumulatore).

> 🖼️ **[INSERIRE QUI IMMAGINE: mac_rtl_schematic.png]**
> *Didascalia: Schematico RTL generato da Vivado per il singolo modulo MAC. Il tool riconosce l'intento e mappa i registri esattamente come lo schema hardware DSP.*

### Catena Sistolica 1D (`Systolic_FIR.vhd`)
I PE sono collegati in una catena monodimensionale tramite un costrutto VHDL `generate`. Il routing interno sfrutta le "autostrade" di silicio dedicate dei DSP AMD (`PCIN`/`PCOUT` per le somme, `ACIN`/`ACOUT` per i dati), mantenendo il segnale fuori dalla matrice di routing generica dell'FPGA.

---

## 3. Metodologia di Simulazione e Verifica

La validazione non si limita all'osservazione delle forme d'onda, ma utilizza un flusso di co-simulazione con **Golden Model**.

### Il Flusso con Golden Model in Python
Uno script Python (`scipy.signal`) genera il segnale di stimolo (utile + rumore) e la risposta matematica ideale. Il FIR hardware opera nel dominio intero: i coefficienti in virgola mobile vengono quantizzati nel formato **16-bit Q15** e salvati in file testuali.

### Testbench in VHDL e Analisi Spettrale
Il modulo `tb_Systolic_FIR.vhd` utilizza la libreria `TEXTIO` per leggere i vettori, stimolare il sistema e riversare l'accumulatore a 48-bit (troncato a 32-bit utili) in `output.txt`. 
Infine, Python legge l'output hardware ed esegue una **Fast Fourier Transform (FFT)** per confrontare lo spettro.

> 🖼️ **[INSERIRE QUI IMMAGINE: python_fft_dashboard.png]**
> *Didascalia: Dashboard generata dallo script Python. In basso a destra, l'analisi FFT dimostra la perfetta sovrapposizione tra il filtro ideale in Python (verde) e il calcolo fixed-point hardware dell'FPGA (rosso tratteggiato).*

### Risultati di Implementazione 
*Dati riferiti alla fase di Post-Implementation (Place & Route completato).*

![App Dashboard Layout](images/dashboard.png)

> *Didascalia: Report di Timing di Vivado che certifica l'assenza di violazioni di Setup/Hold (Slack Positivo) grazie all'assorbimento nativo nei DSP.*

| Target FPGA | Clock Period Constraint | Setup WNS | Max Freq Equivalente ($F_{max}$) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Zynq UltraScale+ (ZCU111)** | 4.0 ns (250 MHz) | +2.94 ns | **~ 1 GHz** (Limitato dal silicio) | 1 Sample / Clock |
| **Artix-7 (Arty A7-35T)** | 10.0 ns (100 MHz) | *TBD* | **> 300 MHz** | 1 Sample / Clock |

---

## 4. Struttura del Repository

```text
├── rtl/
│   ├── my_pkg.vhd          # Definizione tipi custom (memory_array)
│   ├── MAC.vhd             # Processing Element Pipelined
│   └── Systolic_FIR.vhd    # Array Sistolico Top-Level
├── sim/
│   ├── tb_Systolic_FIR.vhd # Testbench VHDL con I/O su file
├── model/
│   └── fir_golden_model.py # Script Python per generazione e FFT
└── README.md
```
## 5. Sviluppi futuri
1. Implementazione di interfaccia AXI-Strem
2. Implementazione di interfaccia AXI-Lite per riconfigurare i pesi
3. Logica di Shift, Round & Saturate per estrarre 16 bit normalizzati dall'accumulatore a 48 bit senza rischio di overflow.
 
