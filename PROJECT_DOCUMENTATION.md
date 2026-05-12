# EA Scalping Price Action - Project Documentation

## Overview
Expert Advisor (EA) scalping yang bergantung pada price action (rejection dan konfirmasi) di area tertentu dengan aturan logika matematis yang kaku.

## Core Principles
- **Objektif & Terukur**: Semua parameter harus berbasis angka, bukan intuisi
- **Edge Statistik**: Menjaga profitabilitas melalui aturan yang ketat
- **Manajemen Risiko Absolut**: Perlindungan modal adalah prioritas utama

---

## 1. Filter Tren (Market Context)

### Tujuan
Menghindari scalping melawan tren utama yang dapat menghancurkan akun.

### Implementasi
- **Indikator**: Exponential Moving Average (EMA)
- **Periode**: EMA 50 dan EMA 200
- **Timeframe**: Lebih tinggi dari timeframe eksekusi (contoh: eksekusi M5, filter H1)

### Aturan
```
IF harga > EMA 200 → Hanya cari setup BUY
IF harga < EMA 200 → Hanya cari setup SELL
```

---

## 2. Identifikasi Area Buy/Sell (Zona Objektif)

### Tujuan
Mendeteksi Supply and Demand (SND) atau Support and Resistance secara otomatis.

### Implementasi
- **Metode 1**: ZigZag + Fibonacci Retracement untuk memetakan struktur pasar
- **Metode 2**: Logika pembentukan base (Rally-Base-Rally / Drop-Base-Drop)

### Aturan Zona
- Setup hanya valid jika zona **belum pernah di-mitigasi** (disentuh kembali)
- **Zone Cleanup**: Hapus zona setelah harga menembus atau merespons zona tersebut

---

## 3. Validasi Trigger: Rejection & Konfirmasi

### 3.1 Rejection Logic

#### Buy Setup (di area Demand)
- Pola: Pinbar/Hammer
- **Rumus Matematis**:
  - `Lower Wick ≥ 2 × Body Length`
  - `Upper Wick sangat kecil`

#### Sell Setup (di area Supply)
- Pola: Shooting Star
- **Rumus Matematis**:
  - `Upper Wick ≥ 2 × Body Length`

### 3.2 Konfirmasi Logic

**PENTING**: EA dilarang entry hanya karena ada rejection!

#### Buy Confirmation
- Candle setelah rejection harus **close lebih tinggi** dari high candle rejection
- Membentuk Bullish Engulfing atau momentum kuat
- Entry dipicu pada **pergantian candle**

#### Sell Confirmation
- Candle setelah rejection harus **close lebih rendah** dari low candle rejection
- Membentuk Bearish Engulfing atau momentum kuat
- Entry dipicu pada **pergantian candle**

---

## 4. Manajemen Risiko Wajib (Non-Negotiable)

### 4.1 Risiko Maksimal 1% per Trade
- **TIDAK menggunakan lot statis**
- Lot dihitung dinamis berdasarkan jarak Stop Loss

#### Rumus Lot Dinamis
```
Lot = (Balance × 1%) / (Jarak SL dalam Poin × Tick Value)
```
- SL lebar → Lot mengecil
- SL sempit → Lot membesar
- Tetap hanya 1% modal yang dikorbankan jika Stop Out

### 4.2 Penempatan Stop Loss (SL) Otomatis
- **Buy**: SL beberapa pips (buffer spread) di bawah low area Demand
- **Sell**: SL beberapa pips (buffer spread) di atas high area Supply

### 4.3 Take Profit (TP) & Risk/Reward Ratio
- **Minimum RR**: 1:1.5 atau 1:2 dari jarak SL
- Memastikan **Positive Expectancy**

---

## 5. Eksekusi & Trade Management Lanjutan

### 5.1 Breakeven (BE) Otomatis
- **Trigger**: Ketika profit mencapai 1R (sebesar jarak SL awal)
- **Aksi**: Pindahkan SL ke titik Entry + komisi/spread
- **Hasil**: Jika harga berbalik, keluar tanpa kerugian

### 5.2 Trailing Stop (TS)
- **Basis**: Indikator ATR (Average True Range) atau struktur ZigZag
- **BUKAN**: Trailing poin statis (mudah tersapu fluktuasi kecil)

### 5.3 Filter Volatilitas & Waktu

#### News Filter
- Tidak beroperasi saat **High Impact News** dirilis

#### Session Filter
- **Hindari**: Sesi Asia (untuk pair mayor)
- **Fokus**: Sesi London dan New York
- **Alasan**: Spread ketat dan likuiditas tinggi

---

## Testing Requirements

### Backtest
- **Data**: Tick 99% (kualitas modelling tertinggi di MT4/MT5)
- **Durasi**: Minimal 2 tahun terakhir

### Forward Test
- **Akun**: Cent atau Demo
- **Durasi**: Minimal 3 bulan

### Evaluasi
- Jika kurva ekuitas turun tajam:
  - Periksa parameter konfirmasi
  - Periksa apakah zona terlalu longgar

---

## Technical Implementation Checklist

- [ ] EMA 50 & 200 untuk trend filter
- [ ] ZigZag indicator untuk zone detection
- [ ] Fibonacci levels calculation
- [ ] Candle pattern recognition (wick/body ratio)
- [ ] Dynamic lot size calculator
- [ ] Automatic SL/TP placement
- [ ] Breakeven logic
- [ ] ATR-based trailing stop
- [ ] Session time filter
- [ ] News filter integration (API required)
- [ ] Zone mitigation tracking
- [ ] Order management system

---

## Next Steps

1. **Setup Development Environment**
   - Install MetaEditor (MT4/MT5)
   - Setup version control (Git)
   - Configure local testing environment

2. **Develop Core Modules**
   - Trend filter module
   - Zone detection module
   - Signal validation module
   - Risk management module
   - Trade execution module

3. **Testing Phase**
   - Unit testing each module
   - Integration testing
   - Backtesting with historical data
   - Forward testing on demo account

4. **Optimization**
   - Parameter tuning
   - Performance analysis
   - Risk adjustment

---

## Notes for Development

- Semua parameter harus dapat dikonfigurasi (input parameters)
- Logging yang detail untuk debugging dan analisis
- Error handling yang robust
- Memory management yang efisien
- Compatible dengan broker standar (ECN/STP)
