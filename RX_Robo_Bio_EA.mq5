//+------------------------------------------------------------------+
//|                                             RX Robo Bio EA.mq5   |
//|                                  Expert Advisor Template Stage 1 |
//|                                           Visual Toggle Switch   |
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.00"
#property strict

//--- Global Variables
bool isAutoTradeActive = false;           // Variabel kontrol utama (Saklar)
string btnName = "RX_Robo_ToggleBtn";     // Nama unik objek tombol
int btnX = 20;                            // Koordinat X tombol (pixel dari kiri)
int btnY = 30;                            // Koordinat Y tombol (pixel dari atas)
int btnXSize = 200;                       // Lebar tombol
int btnYSize = 40;                        // Tinggi tombol

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
   //--- TAHAP 1: Belum ada logika trading
   //--- Logika entry, exit, dan manajemen risiko akan ditambahkan di tahap selanjutnya
   
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
