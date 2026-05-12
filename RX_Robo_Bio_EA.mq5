//+------------------------------------------------------------------+
//|                                             RX Robo Bio EA.mq5   |
//|                                  Expert Advisor - Full Implementation
//|                            Risk Management, Market Context & Trigger Logic
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.03"

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

//--- Handle Indikator Global (Inisialisasi sekali di OnInit)
int emaHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Inisialisasi tombol saklar di chart
   CreateToggleButton();
   
   //--- Update tampilan awal tombol sesuai state variabel
   UpdateToggleButtonState();
   
   //--- Inisialisasi indikator EMA 200 H1 (hanya sekali di sini)
   emaHandle = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle == INVALID_HANDLE)
     {
      Print("ERROR: Failed to create EMA 200 handle in OnInit");
      return(INIT_FAILED);
     }
   
   Print("RX Robo Bio EA initialized. Auto Trading: ", isAutoTradeActive ? "ON" : "OFF");
   Print("Risk Management Module: Locked at ", RISK_PERCENTAGE * 100, "% per trade");
   Print("EMA 200 Handle created successfully: ", emaHandle);
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Hapus objek tombol dari chart untuk mencegah sampah visual
   ObjectDelete(0, btnName);
   
   //--- Release handle indikator EMA
   if(emaHandle != INVALID_HANDLE)
     {
      IndicatorRelease(emaHandle);
      emaHandle = INVALID_HANDLE;
     }
   
   Print("RX Robo Bio EA deinitialized. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Update struktur pasar dan zona setiap tick
   DetectSupplyDemandZones();
   CheckZoneMitigation();
   
   if(isAutoTradeActive)
     {
      //--- Dapatkan arah tren saat ini
      int trend = GetTrendDirection();
      
      //--- Cek kondisi entry berdasarkan mode trading
      if(trend == 1) // Bullish - fokus Buy
        {
         // Cek apakah ada rejection bullish di zona demand
         if(IsPinbarRejection(1) && IsConfirmation(1))
           {
            // Trigger Buy logic akan ditambahkan di tahap selanjutnya
            Print("BUY SIGNAL DETECTED: Pinbar Rejection + Confirmation in Demand Zone");
           }
        }
      else if(trend == -1) // Bearish - fokus Sell
        {
         // Cek apakah ada rejection bearish di zona supply
         if(IsPinbarRejection(-1) && IsConfirmation(-1))
           {
            // Trigger Sell logic akan ditambahkan di tahap selanjutnya
            Print("SELL SIGNAL DETECTED: Pinbar Rejection + Confirmation in Supply Zone");
           }
        }
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
//| PERBAIKAN: Bandingkan Close[1] dengan EMA, bukan harga Bid       |
//+------------------------------------------------------------------+
int GetTrendDirection()
  {
   if(emaHandle == INVALID_HANDLE)
     {
      Print("ERROR: EMA handle not initialized");
      return(0);
     }
   
   //--- Buffer untuk menyimpan nilai EMA
   double emaBuffer[];
   ArraySetAsSeries(emaBuffer, true);
   
   //--- Copy nilai EMA dari candle terakhir (index 0)
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) != 1)
     {
      Print("ERROR: Failed to copy EMA buffer data");
      return(0);
     }
   
   //--- Dapatkan harga close dari candle yang SUDAH SELESAI (Index 1)
   // BUKAN harga Bid saat ini yang masih berjalan
   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   if(CopyClose(_Symbol, _Period, 1, 1, closePrice) != 1)
     {
      Print("ERROR: Failed to copy close price for candle index 1");
      return(0);
     }
   
   //--- Tentukan arah tren berdasarkan perbandingan Close[1] vs EMA
   if(closePrice[0] > emaBuffer[0])
     {
      // Harga di atas EMA 200 = Tren Bullish (fokus Buy)
      return(1);
     }
   else if(closePrice[0] < emaBuffer[0])
     {
      // Harga di bawah EMA 200 = Tren Bearish (fokus Sell)
      return(-1);
     }
   
   //--- Harga sangat dekat dengan EMA = No clear trend
   return(0);
  }

//+------------------------------------------------------------------+
//| Fungsi Deteksi Zona Supply/Demand                                |
//| Implementasi menggunakan algoritma Swing High/Swing Low          |
//+------------------------------------------------------------------+
void DetectSupplyDemandZones()
  {
   //--- Jika zona sudah aktif, jangan buat zona baru (tunggu mitigasi dulu)
   if(zoneIsActive)
     {
      return;
     }
   
   //--- Deteksi Swing High untuk Supply Zone (Sell area)
   // Cari pola: High tertinggi di tengah, diapit oleh 2 high lebih rendah
   int swingLookback = 5; // Jumlah candle di kiri/kanan untuk validasi swing
   double currentHigh = iHigh(_Symbol, _Period, 1);
   
   bool isSwingHigh = true;
   for(int i = 1; i <= swingLookback; i++)
     {
      if(iHigh(_Symbol, _Period, 1 + i) >= currentHigh || 
         iHigh(_Symbol, _Period, 1 - i) >= currentHigh)
        {
         isSwingHigh = false;
         break;
        }
     }
   
   // Jika terdeteksi Swing High, buat Supply Zone
   if(isSwingHigh && !zoneIsActive)
     {
      // Tentukan base (area konsolidasi sebelum drop)
      double baseHigh = iHigh(_Symbol, _Period, 1);
      double baseLow = iLow(_Symbol, _Period, 1);
      
      // Cek apakah ada momentum drop setelah base
      if(iClose(_Symbol, _Period, 0) < iLow(_Symbol, _Period, 2))
        {
         zoneUpperBound = baseHigh;
         zoneLowerBound = baseLow;
         zoneIsActive = true;
         zoneIsMitigated = false;
         
         Print("SUPPLY ZONE DETECTED: Upper=", zoneUpperBound, " Lower=", zoneLowerBound);
        }
     }
   
   //--- Deteksi Swing Low untuk Demand Zone (Buy area)
   double currentLow = iLow(_Symbol, _Period, 1);
   bool isSwingLow = true;
   
   for(int i = 1; i <= swingLookback; i++)
     {
      if(iLow(_Symbol, _Period, 1 + i) <= currentLow || 
         iLow(_Symbol, _Period, 1 - i) <= currentLow)
        {
         isSwingLow = false;
         break;
        }
     }
   
   // Jika terdeteksi Swing Low, buat Demand Zone
   if(isSwingLow && !zoneIsActive)
     {
      // Tentukan base (area konsolidasi sebelum rally)
      double baseHigh = iHigh(_Symbol, _Period, 1);
      double baseLow = iLow(_Symbol, _Period, 1);
      
      // Cek apakah ada momentum rally setelah base
      if(iClose(_Symbol, _Period, 0) > iHigh(_Symbol, _Period, 2))
        {
         zoneUpperBound = baseHigh;
         zoneLowerBound = baseLow;
         zoneIsActive = true;
         zoneIsMitigated = false;
         
         Print("DEMAND ZONE DETECTED: Upper=", zoneUpperBound, " Lower=", zoneLowerBound);
        }
     }
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
         zoneUpperBound = 0;
         zoneLowerBound = 0;
         zoneIsActive = false;
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
   
   //--- Logika mitigasi untuk zona Supply (Sell area)
   if(zoneUpperBound > 0 && zoneLowerBound > 0 && zoneUpperBound > zoneLowerBound)
     {
      // Cek apakah harga sudah menyentuh zona Supply
      if(currentAsk >= zoneLowerBound && currentBid <= zoneUpperBound)
        {
         Print("ZONE MITIGATION: Supply zone touched at ", currentAsk, ". Zone marked as mitigated.");
         zoneIsMitigated = true;
         
         // Reset zona setelah mitigasi (First Time Back rule)
         zoneUpperBound = 0;
         zoneLowerBound = 0;
         zoneIsActive = false;
        }
      
      // Cek apakah harga sudah menembus ke atas zona (invalidates zone)
      if(currentAsk > zoneUpperBound)
        {
         Print("ZONE BREACH: Supply zone broken. Clearing zone coordinates.");
         zoneUpperBound = 0;
         zoneLowerBound = 0;
         zoneIsActive = false;
         zoneIsMitigated = false;
        }
     }
   
   Print("CheckZoneMitigation: Monitoring active zones... IsActive=", zoneIsActive, " IsMitigated=", zoneIsMitigated);
  }

//+------------------------------------------------------------------+
//| TAHAP 4: Logika Trigger (Rejection & Konfirmasi)                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Fungsi Deteksi Pinbar Rejection berdasarkan rasio matematis      |
//| mode: 1 = Bullish (Buy), -1 = Bearish (Sell)                     |
//| Analisis pada Candle Index 1 (candle yang sudah selesai)         |
//+------------------------------------------------------------------+
bool IsPinbarRejection(int mode)
  {
   //--- Pastikan ada zona aktif sebelum cek rejection
   if(!zoneIsActive || zoneUpperBound == 0 || zoneLowerBound == 0)
     {
      return(false);
     }
   
   //--- Ambil data candle index 1 (sudah selesai terbentuk)
   double open1 = iOpen(_Symbol, _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);
   
   //--- Hitung komponen candle
   double bodySize = MathAbs(open1 - close1);
   double upperWick = high1 - MathMax(open1, close1);
   double lowerWick = MathMin(open1, close1) - low1;
   
   //--- Hindari division by zero
   if(bodySize == 0)
     {
      return(false);
     }
   
   //--- Validasi berdasarkan mode
   if(mode == 1) // Bullish Rejection (untuk Buy di Demand Zone)
     {
      // Syarat: Lower Wick >= 2.5x Body DAN Upper Wick <= 0.5x Body
      if(lowerWick < 2.5 * bodySize)
        {
         return(false);
        }
      if(upperWick > 0.5 * bodySize)
        {
         return(false);
        }
      
      // Validasi: Low candle harus berada dalam range zona Demand
      if(low1 > zoneUpperBound || low1 < zoneLowerBound)
        {
         // Harga tidak masuk ke zona demand
         return(false);
        }
      
      Print("BULLISH PINBAR DETECTED: LowerWick=", lowerWick, " Body=", bodySize, " UpperWick=", upperWick);
      return(true);
     }
   else if(mode == -1) // Bearish Rejection (untuk Sell di Supply Zone)
     {
      // Syarat: Upper Wick >= 2.5x Body DAN Lower Wick <= 0.5x Body
      if(upperWick < 2.5 * bodySize)
        {
         return(false);
        }
      if(lowerWick > 0.5 * bodySize)
        {
         return(false);
        }
      
      // Validasi: High candle harus berada dalam range zona Supply
      if(high1 < zoneLowerBound || high1 > zoneUpperBound)
        {
         // Harga tidak masuk ke zona supply
         return(false);
        }
      
      Print("BEARISH PINBAR DETECTED: UpperWick=", upperWick, " Body=", bodySize, " LowerWick=", lowerWick);
      return(true);
     }
   
   return(false);
  }

//+------------------------------------------------------------------+
//| Fungsi Deteksi Konfirmasi Entry                                  |
//| mode: 1 = Bullish (Buy), -1 = Bearish (Sell)                     |
//| Analisis pada Candle Index 0 (candle yang sedang berjalan)       |
//+------------------------------------------------------------------+
bool IsConfirmation(int mode)
  {
   //--- Pastikan ada zona aktif
   if(!zoneIsActive || zoneUpperBound == 0 || zoneLowerBound == 0)
     {
      return(false);
     }
   
   //--- Ambil data candle rejection (index 1)
   double high1 = iHigh(_Symbol, _Period, 1);
   double low1 = iLow(_Symbol, _Period, 1);
   
   //--- Ambil harga saat ini (candle index 0 yang sedang berjalan)
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(mode == 1) // Bullish Confirmation (untuk Buy)
     {
      // Syarat: Harga Bid saat ini harus menembus High dari candle rejection
      if(currentBid > high1)
        {
         Print("BULLISH CONFIRMATION: Price ", currentBid, " broke above rejection high ", high1);
         return(true);
        }
     }
   else if(mode == -1) // Bearish Confirmation (untuk Sell)
     {
      // Syarat: Harga Ask saat ini harus menembus Low dari candle rejection
      if(currentAsk < low1)
        {
         Print("BEARISH CONFIRMATION: Price ", currentAsk, " broke below rejection low ", low1);
         return(true);
        }
     }
   
   return(false);
  }
//+------------------------------------------------------------------+
