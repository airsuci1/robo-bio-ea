//+------------------------------------------------------------------+
//|                                             RX Robo Bio EA.mq5   |
//|                                  Expert Advisor Template Stage 3 |
//|                            Market Context & Structure Mapping    |
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.02"

//--- Global Variables
bool isAutoTradeActive = false;           // Variabel kontrol utama (Saklar)
string btnName = "RX_Robo_ToggleBtn";     // Nama unik objek tombol
int btnX = 20;                            // Koordinat X tombol (pixel dari kiri)
int btnY = 30;                            // Koordinat Y tombol (pixel dari atas)
int btnXSize = 200;                       // Lebar tombol
int btnYSize = 40;                        // Tinggi tombol

//--- Konstanta Manajemen Risiko (Non-Negotiable)
#define RISK_PERCENTAGE 0.01  // Risiko 1% per trade (dikunci mati, tidak bisa diubah)

//--- Variabel untuk Zona Supply/Demand
double zoneUpperBound = 0;
double zoneLowerBound = 0;
bool zoneIsActive = false;
bool zoneIsMitigated = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Inisialisasi tombol saklar di chart
   CreateToggleButton();
   
   //--- Update tampilan awal tombol sesuai state variabel
   UpdateToggleButtonState();
   
   Print("RX Robo Bio EA initialized. Auto Trading: ", isAutoTradeActive ? "ON" : "OFF");
   Print("Risk Management Module: Locked at ", RISK_PERCENTAGE * 100, "% per trade");
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Hapus objek tombol dari chart untuk mencegah sampah visual
   ObjectDelete(0, btnName);
   
   Print("RX Robo Bio EA deinitialized. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- TAHAP 2: Modul Manajemen Risiko siap digunakan
   //--- Logika entry akan ditambahkan di tahap selanjutnya
   
   if(isAutoTradeActive)
     {
      //--- Tempat untuk logika trading saat saklar ON
      //--- Akan diisi pada tahap pengembangan berikutnya
     }
  }

//+------------------------------------------------------------------+
//| Chart event handling function                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   //--- Cek apakah event yang terjadi adalah klik pada objek button
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == btnName)
     {
      //--- Reset status klik tombol agar bisa diklik lagi
      ObjectSetInteger(0, btnName, OBJPROP_STATE, false);
      
      //--- Toggle nilai variabel boolean (True <-> False)
      isAutoTradeActive = !isAutoTradeActive;
      
      //--- Update visual tombol (warna dan teks) sesuai state baru
      UpdateToggleButtonState();
      
      //--- Cetak status ke Journal untuk verifikasi
      Print(">>> TOGGLE TRIGGERED <<< Auto Trading Status: ", isAutoTradeActive ? "ON (Hijau)" : "OFF (Merah)");
     }
  }

//+------------------------------------------------------------------+
//| Fungsi untuk menghitung Lot Dinamis (Manajemen Risiko Wajib)     |
//| Parameter: stopLossPoints = Jarak Stop Loss dalam poin (bukan pip)|
//| Return: double = Ukuran lot yang dihitung secara presisi         |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double stopLossPoints)
  {
   //--- Langkah 1: Hitung jumlah risiko dalam mata uang akun (1% dari Balance)
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RISK_PERCENTAGE;
   
   //--- Langkah 2: Dapatkan informasi simbol untuk perhitungan presisi
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   //--- Validasi data simbol (cegah division by zero)
   if(tickValue <= 0 || tickSize <= 0 || stopLossPoints <= 0)
     {
      Print("ERROR: Invalid symbol data for lot calculation. TickValue=", tickValue, " TickSize=", tickSize, " SL_Points=", stopLossPoints);
      return(0);
     }
   
   //--- Langkah 3: Hitung kerugian untuk 1 lot berdasarkan poin (Rumus Universal)
   // Rumus: Loss per Lot = (StopLossPoints * Point / TickSize) * TickValue
   // Ini bekerja untuk SEMUA instrumen (Forex, XAUUSD, Crypto) tanpa hardcoding
   double lossForOneLot = (stopLossPoints * pointValue / tickSize) * tickValue;
   
   //--- Validasi loss per lot
   if(lossForOneLot <= 0)
     {
      Print("ERROR: Calculated loss for one lot is invalid: ", lossForOneLot);
      return(0);
     }
   
   //--- Langkah 4: Hitung lot teoretis berdasarkan risiko
   // Rumus: Lot = RiskAmount / LossForOneLot
   double lotRaw = riskAmount / lossForOneLot;
   
   //--- Langkah 5: Validasi terhadap batas broker (MIN/MAX/STEP)
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Batasi lot minimal
   if(lotRaw < minLot)
     {
      Print("WARNING: Calculated lot (", lotRaw, ") below minimum. Set to min: ", minLot);
      lotRaw = minLot;
     }
   
   // Batasi lot maksimal
   if(lotRaw > maxLot)
     {
      Print("WARNING: Calculated lot (", lotRaw, ") exceeds maximum. Set to max: ", maxLot);
      lotRaw = maxLot;
     }
   
   //--- Langkah 6: Bulatkan lot sesuai step size broker
   // Contoh: Jika step=0.01 dan lotRaw=0.123, maka jadi 0.12
   double lotNormalized = MathFloor(lotRaw / lotStep) * lotStep;
   
   // Validasi akhir setelah normalisasi
   if(lotNormalized < minLot) lotNormalized = minLot;
   if(lotNormalized > maxLot) lotNormalized = maxLot;
   
   //--- Cetak info perhitungan ke journal untuk debugging
   Print("LOT CALCULATION [Stage 3]: Balance=", AccountInfoDouble(ACCOUNT_BALANCE), 
         " RiskAmt=", riskAmount, 
         " SL(Points)=", stopLossPoints, 
         " TickValue=", tickValue,
         " TickSize=", tickSize,
         " Point=", pointValue,
         " LossPerLot=", lossForOneLot,
         " RawLot=", lotRaw, 
         " NormalizedLot=", lotNormalized);
   
   return(lotNormalized);
  }

//+------------------------------------------------------------------+
//| Fungsi untuk membuat objek tombol di chart                       |
//+------------------------------------------------------------------+
void CreateToggleButton()
  {
   //--- Hapus tombol jika sudah ada (untuk keamanan saat re-init)
   ObjectDelete(0, btnName);
   
   //--- Buat objek button baru
   ObjectCreate(0, btnName, OBJ_BUTTON, 0, 0, 0);
   
   //--- Atur properti dasar tombol
   ObjectSetInteger(0, btnName, OBJPROP_XDISTANCE, btnX);          // Posisi X
   ObjectSetInteger(0, btnName, OBJPROP_YDISTANCE, btnY);          // Posisi Y
   ObjectSetInteger(0, btnName, OBJPROP_XSIZE, btnXSize);          // Lebar
   ObjectSetInteger(0, btnName, OBJPROP_YSIZE, btnYSize);          // Tinggi
   ObjectSetString(0, btnName, OBJPROP_TEXT, "RX ROBO: OFF");      // Teks awal
   ObjectSetString(0, btnName, OBJPROP_FONT, "Arial Bold");        // Font
   ObjectSetInteger(0, btnName, OBJPROP_FONTSIZE, 10);             // Ukuran font
   ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);          // Warna teks
   ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDimGray);      // Warna latar belakang
   ObjectSetInteger(0, btnName, OBJPROP_BORDER_COLOR, clrBlack);   // Warna border
   ObjectSetInteger(0, btnName, OBJPROP_CORNER, CORNER_LEFT_UPPER);// Posisi sudut (Kiri Atas)
   ObjectSetInteger(0, btnName, OBJPROP_SELECTABLE, false);        // Tidak bisa dipilih/drag
   ObjectSetInteger(0, btnName, OBJPROP_HIDDEN, true);             // Sembunyikan dari daftar objek
  }

//+------------------------------------------------------------------+
//| Fungsi untuk update visual tombol berdasarkan state              |
//+------------------------------------------------------------------+
void UpdateToggleButtonState()
  {
   if(isAutoTradeActive)
     {
      //--- State AKTIF: Hijau
      ObjectSetString(0, btnName, OBJPROP_TEXT, "RX ROBO: ON");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkGreen);
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
     }
   else
     {
      //--- State MATI: Merah
      ObjectSetString(0, btnName, OBJPROP_TEXT, "RX ROBO: OFF");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, clrDarkRed);
      ObjectSetInteger(0, btnName, OBJPROP_COLOR, clrWhite);
     }
   
   //--- Refresh chart agar perubahan langsung terlihat
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| TAHAP 3: Modul Pemetaan Struktur Pasar (Market Context)          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Fungsi Filter Tren: Menggunakan EMA 200                          |
//| Return: 1 = Bullish (Buy only), -1 = Bearish (Sell only), 0 = No Trend |
//+------------------------------------------------------------------+
int GetTrendDirection()
  {
   //--- Buat handle untuk indikator EMA 200 pada timeframe H1
   int emaHandle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaHandle == INVALID_HANDLE)
     {
      Print("ERROR: Failed to create EMA 200 handle");
      return(0);
     }
   
   //--- Buffer untuk menyimpan nilai EMA
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   
   //--- Copy nilai EMA dari candle terakhir
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) != 1)
     {
      Print("ERROR: Failed to copy EMA buffer data");
      IndicatorRelease(emaHandle);
      return(0);
     }
   
   //--- Dapatkan harga close candle terakhir
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   //--- Release handle untuk efisiensi memori
   IndicatorRelease(emaHandle);
   
   //--- Tentukan arah tren
   if(currentPrice > emaBuffer[0])
     {
      // Harga di atas EMA 200 = Tren Bullish (fokus Buy)
      return(1);
     }
   else if(currentPrice < emaBuffer[0])
     {
      // Harga di bawah EMA 200 = Tren Bearish (fokus Sell)
      return(-1);
     }
   
   //--- Harga sangat dekat dengan EMA = No clear trend
   return(0);
  }

//+------------------------------------------------------------------+
//| Fungsi Deteksi Zona Supply/Demand                                |
//| Placeholder untuk logika deteksi menggunakan ZigZag/Fibonacci    |
//+------------------------------------------------------------------+
void DetectSupplyDemandZones()
  {
   //--- TAHAP 3: Kerangka deteksi zona Supply/Demand
   // TODO: Implementasi logika deteksi pola Rally-Base-Drop / Drop-Base-Rally
   // TODO: Gunakan ZigZag dan Fibonacci Retracement untuk mapping struktur
   // TODO: Simpan koordinat ke zoneUpperBound dan zoneLowerBound
   
   // Contoh placeholder (akan diganti dengan logika sebenarnya):
   // zoneUpperBound = ...; // High tertinggi dari Base
   // zoneLowerBound = ...; // Low terendah dari Body Base
   // zoneIsActive = true;
   
   Print("DetectSupplyDemandZones: Framework ready. Implementation pending.");
  }

//+------------------------------------------------------------------+
//| Fungsi Zone Cleanup (Mitigasi): Cek apakah zona sudah disentuh   |
//| Reset zona jika First Time Back sudah terjadi                    |
//+------------------------------------------------------------------+
void CheckZoneMitigation()
  {
   //--- Jika tidak ada zona aktif, keluar
   if(!zoneIsActive || zoneIsMitigated)
     {
      return;
     }
   
   //--- Dapatkan harga saat ini
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Logika mitigasi untuk zona Demand (Buy area)
   // Jika harga menyentuh atau menembus zona dari bawah
   if(zoneLowerBound > 0 && zoneUpperBound > zoneLowerBound)
     {
      // Cek apakah harga sudah menyentuh zona Demand
      if(currentBid <= zoneUpperBound && currentAsk >= zoneLowerBound)
        {
         Print("ZONE MITIGATION: Demand zone touched at ", currentBid, ". Zone marked as mitigated.");
         zoneIsMitigated = true;
         
         // Reset zona setelah mitigasi (First Time Back rule)
         // zoneUpperBound = 0;
         // zoneLowerBound = 0;
         // zoneIsActive = false;
        }
      
      // Cek apakah harga sudah menembus ke bawah zona (invalidates zone)
      if(currentBid < zoneLowerBound)
        {
         Print("ZONE BREACH: Demand zone broken. Clearing zone coordinates.");
         zoneUpperBound = 0;
         zoneLowerBound = 0;
         zoneIsActive = false;
         zoneIsMitigated = false;
        }
     }
   
   //--- Logika mitigasi untuk zona Supply (Sell area) - akan ditambahkan nanti
   // TODO: Implementasi simetris untuk zona Supply
   
   Print("CheckZoneMitigation: Monitoring active zones...");
  }
//+------------------------------------------------------------------+
