//+------------------------------------------------------------------+
//|                                             RX Robo Bio EA.mq5   |
//|                                  Expert Advisor Template Stage 2 |
//|                                     Dynamic Lot Size Calculation |
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.01"
#property strict

//--- Global Variables
bool isAutoTradeActive = false;           // Variabel kontrol utama (Saklar)
string btnName = "RX_Robo_ToggleBtn";     // Nama unik objek tombol
int btnX = 20;                            // Koordinat X tombol (pixel dari kiri)
int btnY = 30;                            // Koordinat Y tombol (pixel dari atas)
int btnXSize = 200;                       // Lebar tombol
int btnYSize = 40;                        // Tinggi tombol

//--- Konstanta Manajemen Risiko (Non-Negotiable)
#define RISK_PERCENTAGE 0.01  // Risiko 1% per trade (dikunci mati, tidak bisa diubah)

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
//| Parameter: stopLossPips = Jarak Stop Loss dalam pips             |
//| Return: double = Ukuran lot yang dihitung secara presisi         |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double stopLossPips)
  {
   //--- Langkah 1: Hitung jumlah risiko dalam mata uang akun (1% dari Balance)
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RISK_PERCENTAGE;
   
   //--- Langkah 2: Dapatkan informasi simbol untuk perhitungan presisi
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   //--- Validasi data simbol (cegah division by zero)
   if(tickValue <= 0 || tickSize <= 0 || stopLossPips <= 0)
     {
      Print("ERROR: Invalid symbol data for lot calculation. TickValue=", tickValue, " TickSize=", tickSize, " SL=", stopLossPips);
      return(0);
     }
   
   //--- Langkah 3: Hitung nilai per pip untuk 1 lot
   // Rumus: Nilai per pip = (TickValue / TickSize) * (1 pip dalam poin)
   // Di MQL5, 1 pip biasanya = 10 poin untuk 5 digit, atau 1 poin untuk 4 digit
   // Kita gunakan pendekatan universal berdasarkan TickSize
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pipValuePerLot = (tickValue / tickSize) * (stopLossPips * pointValue * 10); // Asumsi standar 5 digit
   
   // Koreksi untuk pair yang tidak standar (seperti JPY atau Crypto)
   // Jika tickSize != point*10, sesuaikan perhitungan
   if(MathAbs(tickSize - pointValue * 10) > pointValue) 
     {
      // Untuk pair seperti JPY (3 digit) atau format khusus
      pipValuePerLot = (tickValue / tickSize) * stopLossPips * pointValue;
     }
   
   //--- Langkah 4: Hitung lot teoretis berdasarkan risiko
   // Rumus: Lot = RiskAmount / (StopLossPips * PipValuePerLot)
   double lotRaw = riskAmount / (stopLossPips * (tickValue / tickSize) * pointValue * 10);
   
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
   Print("LOT CALCULATION: Balance=", AccountInfoDouble(ACCOUNT_BALANCE), 
         " RiskAmt=", riskAmount, 
         " SL(pips)=", stopLossPips, 
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
