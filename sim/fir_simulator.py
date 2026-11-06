import numpy as np
import scipy.signal as signal
import matplotlib.pyplot as plt
import os

# ==========================================
# 1. PARAMETERS
# ==========================================
FS = 1000.0         # Sampling frequency (Hz)
F1 = 20.0           # Frequency 1(Hz)
F2 = 100.0          # Frequency 2 (Hz)
N_SAMPLES = 2000    # Samples number

TAPS = 17           # Taps number
FILTER_TYPE = 'low' # Filter type
FC = 100.0          # Cut-off frequency (Hz)

# cast to 16 signed 
Q_MAX = (2**15) - 1 # 32767

# ==========================================
# 2. SIGNAL GENERATION
# ==========================================
t = np.arange(N_SAMPLES) / FS
s1 = 0.5 * np.sin(2 * np.pi * F1 * t)
s2 = 0.5 * np.sin(2 * np.pi * F2 * t)
x_in = s1 + s2 

# ==========================================
# 3. FILTER COEFFICIENTS AND QUANTIZATION
# ==========================================
pass_zero = True if FILTER_TYPE == 'low' else False
coeffs = signal.firwin(TAPS, FC, fs=FS, pass_zero=pass_zero)

coeffs_q15 = np.int16(np.round(coeffs * Q_MAX))
x_in_q15   = np.int16(np.round(x_in * Q_MAX))

# Salvataggio per il Testbench
np.savetxt("coeffs.txt", coeffs_q15, fmt="%d")
np.savetxt("samples.txt", x_in_q15, fmt="%d")

# ==========================================
# 4. READING DATA FROM HW TEST-BENCH
# ==========================================
fpga_output_exists = os.path.exists("output.txt")
if fpga_output_exists:
    y_fpga_raw = np.loadtxt("output.txt", dtype=np.int64)
    y_fpga_norm = y_fpga_raw / float(Q_MAX**2)

y_ideal = signal.lfilter(coeffs, 1.0, x_in)

# ==========================================
# 5. FFT (Spectral Analysis) 
# ==========================================
freqs = np.fft.rfftfreq(N_SAMPLES, 1/FS)
fft_in = np.abs(np.fft.rfft(x_in)) * 2 / N_SAMPLES
fft_ideal = np.abs(np.fft.rfft(y_ideal)) * 2 / N_SAMPLES
if fpga_output_exists:
    min_len = min(N_SAMPLES, len(y_fpga_norm))
    fft_fpga = np.abs(np.fft.rfft(y_fpga_norm[:min_len], n=N_SAMPLES)) * 2 / N_SAMPLES

# ==========================================
# 6. PLOT
# ==========================================
fig = plt.figure(figsize=(16, 12))
gs = fig.add_gridspec(3, 2, height_ratios=[1, 1.2, 1.2], hspace=0.35)

view_samples = int(0.1 * FS) 

# -- PLOT 1 --
ax1 = fig.add_subplot(gs[0, :])
w, h = signal.freqz(coeffs_q15, worN=1024, fs=FS)
h_norm = np.abs(h) / Q_MAX 
ax1.plot(w, 20 * np.log10(np.maximum(h_norm, 1e-10)), 'b')
ax1.axvline(FC, color='red', linestyle='--', label='Taglio (Cutoff)')
ax1.set_title(f'Risposta in Frequenza FIR Matematico ({TAPS} Taps, Q15)')
ax1.set_ylabel('Magnitudo [dB]')
ax1.set_xlabel('Frequenza [Hz]')
ax1.grid(True)
ax1.legend()

# -- PLOT 2 --
ax2 = fig.add_subplot(gs[1, 0])
ax2.plot(t[:view_samples], x_in[:view_samples], 'k', label='Mixed Signal (F1+F2)')
ax2.plot(t[:view_samples], s1[:view_samples], 'r--', alpha=0.7, label=f'Utile ({F1}Hz)')
ax2.set_title('Dominio del Tempo - Segnale in Ingresso')
ax2.set_xlabel('Tempo [s]')
ax2.set_ylabel('Ampiezza')
ax2.grid(True)
ax2.legend()

# -- PLOT 3: FFT  (Input) --
ax3 = fig.add_subplot(gs[1, 1])
ax3.plot(freqs, fft_in, 'k', label='Spettro Ingresso (F1+F2)')
ax3.axvline(F1, color='green', linestyle=':', alpha=0.7, label=f'Segnale {F1}Hz')
ax3.axvline(F2, color='red', linestyle=':', alpha=0.7, label=f'Rumore {F2}Hz')
ax3.set_title('Spettro di Frequenza - Segnale in Ingresso')
ax3.set_xlabel('Frequenza [Hz]')
ax3.set_ylabel('Ampiezza')
ax3.set_xlim(0, FS/2)
ax3.grid(True)
ax3.legend()

# -- PLOT 4 --
ax4 = fig.add_subplot(gs[2, 0])
ax4.plot(t[:view_samples], y_ideal[:view_samples], 'g-', linewidth=3, alpha=0.5, label='Ideale (Python)')
if fpga_output_exists:
    HW_LATENCY = TAPS + 2 
    t_fpga = (np.arange(len(y_fpga_norm)) - HW_LATENCY) / FS
    valid_idx = (t_fpga >= 0) & (t_fpga < (view_samples / FS))
    ax4.plot(t_fpga[valid_idx], y_fpga_norm[valid_idx], 'r--', label='FPGA RTL')
ax4.set_title('Dominio del Tempo - Segnale Filtrato')
ax4.set_xlabel('Tempo [s]')
ax4.set_ylabel('Ampiezza')
ax4.grid(True)
ax4.legend(loc='lower right')

# -- PLOT 5: FFT (output) --
ax5 = fig.add_subplot(gs[2, 1])
ax5.plot(freqs, fft_ideal, 'g-', linewidth=3, alpha=0.5, label='Spettro Filtrato (Python)')
if fpga_output_exists:
    ax5.plot(freqs, fft_fpga, 'r--', linewidth=2, label='Spettro Filtrato (FPGA)')
ax5.set_title('Spettro di Frequenza - Segnale Filtrato')
ax5.set_xlabel('Frequenza [Hz]')
ax5.set_ylabel('Ampiezza')
ax5.set_xlim(0, FS/2)
ax5.grid(True)
ax5.legend()

plt.show()
