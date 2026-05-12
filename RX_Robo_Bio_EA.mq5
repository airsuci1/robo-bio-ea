//+------------------------------------------------------------------+
//|                                             RX_Robo_Bio_EA.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.05"
#property description "Scalping EA with Price Action, Dynamic Risk, and Visual Zones"

#include <Trade\Trade.mqh>

//--- Variabel Kontrol Global
bool isAutoTradeActive = false;
string BUTTON_NAME = "RxRoboToggleButton";

//--- Variabel Manajemen Risiko & Eksekusi
double zoneUpperBound = 0;
double zoneLowerBound = 0;
bool zoneIsActive = false;
bool zoneIsMitigated = false;
string currentZoneType = ""; // "Demand" atau "Supply"

datetime lastTradeTime = 0; // Anti Tick-Spam
CTrade trade;

//--- Variabel Indikator
int emaHandle;
double emaBuffer[];

//+------------------------------------------------------------------+
//| Fungsi Inisialisasi                                              |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. Setup Tombol
    if(!ObjectCreate(0, BUTTON_NAME, OBJ_BUTTON, 0, 0, 0))
    {
        Print("Gagal membuat tombol: ", GetLastError());
        return INIT_FAILED;
    }
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XSIZE, 120);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YSIZE, 30);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrRed);
    ObjectSetString(0, BUTTON_NAME, OBJPROP_TEXT, "RX ROBO: OFF");
    
    // 2. Setup Indikator EMA (Hanya sekali di sini)
    emaHandle = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);
    if(emaHandle == INVALID_HANDLE)
    {
        Print("Gagal membuat handle EMA: ", GetLastError());
        return INIT_FAILED;
    }
    
    ArraySetAsSeries(emaBuffer, true);
    
    Print("RX Robo Bio EA Initialized.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Fungsi De-inisialisasi                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Hapus tombol
    ObjectDelete(0, BUTTON_NAME);
    // Hapus semua objek rectangle zona
    ObjectsDeleteAll(0, "ZoneRect_");
    // Rilis handle indikator
    IndicatorRelease(emaHandle);
    Print("RX Robo Bio EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Fungsi Tick Utama                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!isAutoTradeActive) return;

    // --- ANTI TICK-SPAM FILTER ---
    datetime currentCandleTime = iTime(_Symbol, _Period, 0);
    if(currentCandleTime == lastTradeTime) return; // Hanya 1 trade per candle

    // 1. Cek Tren
    int trend = GetTrendDirection();
    if(trend == 0) return; // Tidak ada tren jelas

    // 2. Deteksi/Update Zona
    DetectSupplyDemandZones(trend);

    // 3. Cek Mitigasi Zona (Hapus jika sudah disentuh/broken)
    CheckZoneMitigation();

    // Jika tidak ada zona aktif, jangan lanjut ke entry
    if(!zoneIsActive) return;

    // 4. Cek Sinyal Entry
    bool signalBuy = (trend == 1 && IsPinbarRejection(1) && IsConfirmation(1));
    bool signalSell = (trend == -1 && IsPinbarRejection(-1) && IsConfirmation(-1));

    if(signalBuy)
    {
        ExecuteBuyOrder();
        lastTradeTime = currentCandleTime; // Kunci waktu trade
    }
    else if(signalSell)
    {
        ExecuteSellOrder();
        lastTradeTime = currentCandleTime; // Kunci waktu trade
    }
}

//+------------------------------------------------------------------+
//| Event Chart (Tombol)                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == BUTTON_NAME)
    {
        isAutoTradeActive = !isAutoTradeActive;
        UpdateButtonDisplay();
        Print("Status Auto Trading: ", isAutoTradeActive ? "ON" : "OFF");
    }
}

void UpdateButtonDisplay()
{
    if(isAutoTradeActive)
    {
        ObjectSetString(0, BUTTON_NAME, OBJPROP_TEXT, "RX ROBO: ON");
        ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrLimeGreen);
    }
    else
    {
        ObjectSetString(0, BUTTON_NAME, OBJPROP_TEXT, "RX ROBO: OFF");
        ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrRed);
    }
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Modul 1: Filter Tren (EMA 200)                                  |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    if(CopyBuffer(emaHandle, 0, 0, 2, emaBuffer) != 2) return 0;
    
    double close1 = iClose(_Symbol, _Period, 1);
    double ema1 = emaBuffer[1]; // Nilai EMA candle sebelumnya
    
    if(close1 > ema1) return 1;  // Uptrend
    if(close1 < ema1) return -1; // Downtrend
    return 0;
}

//+------------------------------------------------------------------+
//| Modul 2: Deteksi Zona Supply/Demand (Swing High/Low)            |
//+------------------------------------------------------------------+
void DetectSupplyDemandZones(int trend)
{
    // Hanya cari zona baru jika belum ada zona aktif
    if(zoneIsActive) return;

    int lookback = 20;
    double highestHigh = 0, lowestLow = 999999;
    int highIndex = 0, lowIndex = 0;

    // Cari Swing High/Low sederhana dari candle yang SUDAH SELESAI (index 1 ke atas)
    for(int i = 1; i <= lookback; i++)
    {
        double high = iHigh(_Symbol, _Period, i);
        double low = iLow(_Symbol, _Period, i);
        
        if(high > highestHigh) { highestHigh = high; highIndex = i; }
        if(low < lowestLow) { lowestLow = low; lowIndex = i; }
    }

    // Logika Sederhana Pembentukan Zona (Base Detection)
    // Demand: Setelah penurunan tajam, ada base kecil, lalu kenaikan
    // Supply: Setelah kenaikan tajam, ada base kecil, lalu penurunan
    
    // Contoh deteksi Demand (Sederhana):
    if(trend == 1) 
    {
        // Cek apakah ada potensi Demand Zone di area terendah terakhir
        // Di sini kita simulasikan zona di sekitar Low terakhir sebagai contoh
        // Dalam implementasi nyata, logika pola 3 candle (Rally-Base-Drop) dimasukkan di sini
        
        double baseHigh = iHigh(_Symbol, _Period, lowIndex + 1);
        double baseLow = iLow(_Symbol, _Period, lowIndex + 1);
        
        // Validasi sederhana: Base harus kecil
        if((baseHigh - baseLow) < (iATR(_Symbol, _Period, 14, 1) * 0.5))
        {
            zoneLowerBound = baseLow;
            zoneUpperBound = baseHigh;
            zoneIsActive = true;
            currentZoneType = "Demand";
            
            // VISUALISASI ZONA
            DrawZone("ZoneRect_Demand", zoneUpperBound, zoneLowerBound, clrBlue);
            Print("Demand Zone Detected: ", zoneLowerBound, " - ", zoneUpperBound);
        }
    }
    // Contoh deteksi Supply (Sederhana):
    else if(trend == -1)
    {
        double baseHigh = iHigh(_Symbol, _Period, highIndex + 1);
        double baseLow = iLow(_Symbol, _Period, highIndex + 1);

        if((baseHigh - baseLow) < (iATR(_Symbol, _Period, 14, 1) * 0.5))
        {
            zoneLowerBound = baseLow;
            zoneUpperBound = baseHigh;
            zoneIsActive = true;
            currentZoneType = "Supply";
            
            // VISUALISASI ZONA
            DrawZone("ZoneRect_Supply", zoneUpperBound, zoneLowerBound, clrRed);
            Print("Supply Zone Detected: ", zoneLowerBound, " - ", zoneUpperBound);
        }
    }
}

//+------------------------------------------------------------------+
//| Fungsi Visualisasi Zona (OBJ_RECTANGLE)                         |
//+------------------------------------------------------------------+
void DrawZone(string name, double upper, double lower, color clr)
{
    // Hapus dulu jika ada nama sama
    ObjectDelete(0, name);
    
    datetime timeStart = iTime(_Symbol, _Period, 10);
    datetime timeEnd = iTime(_Symbol, _Period, 0) + PeriodSeconds() * 5; // Perpanjang ke kanan
    
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeStart, upper, timeEnd, lower))
    {
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true); // Di belakang candle
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        
        // Transparansi (Alpha) bisa diatur via properti lain jika perlu, 
        // tapi Fill=true dengan warna standar sudah cukup terlihat
    }
}

//+------------------------------------------------------------------+
//| Modul 3: Cek Mitigasi & Cleanup Zona                            |
//+------------------------------------------------------------------+
void CheckZoneMitigation()
{
    if(!zoneIsActive) return;

    double currentPrice = (currentZoneType == "Demand") ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    bool broken = false;

    // Cek jika harga menembus zona (Mitigated/Broken)
    if(currentZoneType == "Demand" && currentPrice < zoneLowerBound) broken = true;
    if(currentZoneType == "Supply" && currentPrice > zoneUpperBound) broken = true;

    if(broken)
    {
        // Hapus Visual
        string rectName = (currentZoneType == "Demand") ? "ZoneRect_Demand" : "ZoneRect_Supply";
        ObjectDelete(0, rectName);
        
        // Reset Variabel
        zoneUpperBound = 0;
        zoneLowerBound = 0;
        zoneIsActive = false;
        zoneIsMitigated = true;
        currentZoneType = "";
        
        Print("Zone Mitigated/Broken. Cleanup done.");
    }
}

//+------------------------------------------------------------------+
//| Modul 4: Logika Rejection (Pinbar)                              |
//+------------------------------------------------------------------+
bool IsPinbarRejection(int mode)
{
    int idx = 1; // Cek candle sebelumnya (sudah selesai)
    double open = iOpen(_Symbol, _Period, idx);
    double close = iClose(_Symbol, _Period, idx);
    double high = iHigh(_Symbol, _Period, idx);
    double low = iLow(_Symbol, _Period, idx);
    
    double bodySize = MathAbs(open - close);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    // Hindari pembagian nol
    if(bodySize == 0) return false;

    if(mode == 1) // Buy: Butuh Pinbar Bullish di Area Demand
    {
        // Syarat: Lower Wick >= 2.5 * Body, Upper Wick <= 0.5 * Body
        bool rejectionShape = (lowerWick >= 2.5 * bodySize) && (upperWick <= 0.5 * bodySize);
        
        // Syarat Posisi: Low candle harus di dalam atau dekat zona Demand
        bool inZone = (low <= zoneUpperBound && low >= zoneLowerBound);
        
        return (rejectionShape && inZone);
    }
    else if(mode == -1) // Sell: Butuh Pinbar Bearish di Area Supply
    {
        // Syarat: Upper Wick >= 2.5 * Body, Lower Wick <= 0.5 * Body
        bool rejectionShape = (upperWick >= 2.5 * bodySize) && (lowerWick <= 0.5 * bodySize);
        
        // Syarat Posisi: High candle harus di dalam atau dekat zona Supply
        bool inZone = (high >= zoneLowerBound && high <= zoneUpperBound);
        
        return (rejectionShape && inZone);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Modul 5: Logika Konfirmasi                                      |
//+------------------------------------------------------------------+
bool IsConfirmation(int mode)
{
    // Konfirmasi: Harga saat ini (SymbolInfoDouble(_Symbol, SYMBOL_BID)/SymbolInfoDouble(_Symbol, SYMBOL_ASK)) menembus High/Low candle rejection (index 1)
    double highPrev = iHigh(_Symbol, _Period, 1);
    double lowPrev = iLow(_Symbol, _Period, 1);
    
    if(mode == 1) // Buy Confirmation
    {
        return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) > highPrev);
    }
    else if(mode == -1) // Sell Confirmation
    {
        return (SymbolInfoDouble(_Symbol, SYMBOL_BID) < lowPrev);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Modul 6: Eksekusi Order (Buy)                                   |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
    double slPrice = zoneLowerBound - (30 * _Point); // Buffer 3 pips (asumsi 5 digit)
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double stopLossPoints = (entryPrice - slPrice) / _Point;
    double lotSize = CalculateDynamicLot(stopLossPoints);
    
    if(lotSize <= 0) 
    {
        Print("Error: Lot size invalid for Buy.");
        return;
    }
    
    double tpPrice = entryPrice + (stopLossPoints * 1.5 * _Point);
    
    // Eksekusi
    if(trade.Buy(lotSize, _Symbol, entryPrice, slPrice, tpPrice, "RX Robo Buy"))
    {
        Print("BUY EXECUTED: Lot=", lotSize, " SL=", slPrice, " TP=", tpPrice);
        
        // Reset Zona setelah eksekusi sukses
        ObjectDelete(0, "ZoneRect_Demand");
        zoneUpperBound = 0;
        zoneLowerBound = 0;
        zoneIsActive = false;
        currentZoneType = "";
    }
    else
    {
        Print("BUY FAILED: ", GetLastError(), " ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Modul 7: Eksekusi Order (Sell)                                  |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
    double slPrice = zoneUpperBound + (30 * _Point); // Buffer 3 pips
    double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double stopLossPoints = (slPrice - entryPrice) / _Point;
    double lotSize = CalculateDynamicLot(stopLossPoints);
    
    if(lotSize <= 0) 
    {
        Print("Error: Lot size invalid for Sell.");
        return;
    }
    
    double tpPrice = entryPrice - (stopLossPoints * 1.5 * _Point);
    
    // Eksekusi
    if(trade.Sell(lotSize, _Symbol, entryPrice, slPrice, tpPrice, "RX Robo Sell"))
    {
        Print("SELL EXECUTED: Lot=", lotSize, " SL=", slPrice, " TP=", tpPrice);
        
        // Reset Zona setelah eksekusi sukses
        ObjectDelete(0, "ZoneRect_Supply");
        zoneUpperBound = 0;
        zoneLowerBound = 0;
        zoneIsActive = false;
        currentZoneType = "";
    }
    else
    {
        Print("SELL FAILED: ", GetLastError(), " ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Modul 8: Hitung Lot Dinamis (Risk 1%)                           |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double stopLossPoints)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * 0.01; // 1% Fixed
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue == 0 || tickSize == 0) return 0;
    
    // Rumus Universal: Loss per 1 lot = (SL_Points * Point / TickSize) * TickValue
    double lossPerLot = (stopLossPoints * _Point / tickSize) * tickValue;
    
    if(lossPerLot == 0) return 0;
    
    double rawLot = riskAmount / lossPerLot;
    
    // Normalisasi ke step lot broker
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double finalLot = NormalizeDouble(rawLot / stepLot, 0) * stepLot;
    
    if(finalLot < minLot) finalLot = minLot;
    if(finalLot > maxLot) finalLot = maxLot;
    
    return finalLot;
}
//+------------------------------------------------------------------+
