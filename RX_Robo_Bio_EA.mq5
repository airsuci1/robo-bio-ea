//+------------------------------------------------------------------+
//|                                             RX_Robo_Bio_EA.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "RX Robo Bio EA"
#property version   "1.05"
#property description "Scalping EA with Strict Risk Management & Price Action"

#include <Trade\Trade.mqh>

//--- Input Parameters (Visual Only, Logic is Hardcoded)
input group "--- Visual Settings ---"
input color ColorDemand = clrBlue;
input color ColorSupply = clrRed;

//--- Global Variables
bool isAutoTradeActive = false;
#define BUTTON_NAME "RxRoboToggleButton"

//--- Risk Management Constants
const double RISK_PERCENTAGE = 0.01; // Fixed 1% Risk

//--- Zone Variables
double zoneUpperBound = 0;
double zoneLowerBound = 0;
bool zoneIsActive = false;
string zoneName = "ActiveZoneRect";

//--- Trade Execution Variables
datetime lastTradeTime = 0;
CTrade trade;

//--- Indicator Handles
int emaHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // 1. Initialize Trade Object
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    // 2. Initialize EMA Handle (Trend Filter)
    emaHandle = iMA(_Symbol, _Period, 200, 0, MODE_EMA, PRICE_CLOSE);
    if(emaHandle == INVALID_HANDLE)
    {
        Print("Error creating EMA handle");
        return INIT_FAILED;
    }

    // 3. Create Toggle Button
    if(!ObjectCreate(0, BUTTON_NAME, OBJ_BUTTON, 0, 0, 0))
    {
        Print("Failed to create button");
        return INIT_FAILED;
    }
    
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_YSIZE, 30);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_BGCOLOR, clrDarkGray);
    ObjectSetInteger(0, BUTTON_NAME, OBJPROP_FONTSIZE, 10);
    
    UpdateButtonDisplay();
    
    Print("RX Robo Bio EA Initialized. Waiting for setup...");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up objects
    ObjectDelete(0, BUTTON_NAME);
    ObjectDelete(0, zoneName);
    
    // Release indicator handles
    if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
    
    Print("RX Robo Bio EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 1. Check Auto Trading Status
    if(!isAutoTradeActive) return;

    // 2. Anti-Tick Spamming: Ensure only 1 trade per candle
    datetime currentCandleTime = iTime(_Symbol, _Period, 0);
    if(currentCandleTime == lastTradeTime) return;

    // 3. Get Current Prices (MQL5 Standard)
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // 4. Detect Zones if not active
    if(!zoneIsActive)
    {
        DetectSupplyDemandZones();
    }
    else
    {
        // Check Mitigation (Zone Cleanup)
        CheckZoneMitigation(ask, bid);
        
        // If zone still active, check for Entry
        if(zoneIsActive)
        {
            int trend = GetTrendDirection();
            
            // BUY LOGIC
            if(trend == 1) // Uptrend
            {
                if(IsPinbarRejection(1) && IsConfirmation(1))
                {
                    ExecuteBuyOrder(ask, bid);
                    lastTradeTime = currentCandleTime; // Lock candle
                    return; 
                }
            }
            
            // SELL LOGIC
            if(trend == -1) // Downtrend
            {
                if(IsPinbarRejection(-1) && IsConfirmation(-1))
                {
                    ExecuteSellOrder(ask, bid);
                    lastTradeTime = currentCandleTime; // Lock candle
                    return;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == BUTTON_NAME)
    {
        isAutoTradeActive = !isAutoTradeActive;
        UpdateButtonDisplay();
        Print("Auto Trading Status: ", isAutoTradeActive ? "ON" : "OFF");
        ObjectSetInteger(0, BUTTON_NAME, OBJPROP_STATE, false); // Reset button state
    }
}

//+------------------------------------------------------------------+
//| Helper: Update Button Display                                    |
//+------------------------------------------------------------------+
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
//| Module 1: Dynamic Lot Calculation (Fixed 1% Risk)                |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double stopLossPoints)
{
    if(stopLossPoints <= 0) return 0;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RISK_PERCENTAGE;
    
    // FIXED: Use SYMBOL_TRADE_TICK_VALUE instead of SYMBOL_TICK_VALUE
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(tickValue <= 0 || tickSize <= 0) 
    {
        Print("Error: Invalid Tick Value/Size");
        return 0;
    }

    // Universal Formula: Loss per lot = (SL Points * Point / TickSize) * TickValue
    double lossPerLot = (stopLossPoints * point / tickSize) * tickValue;
    
    if(lossPerLot <= 0) return 0;

    double lotRaw = riskAmount / lossPerLot;
    
    // Normalize to broker limits
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    double lot = NormalizeDouble(lotRaw / stepLot, 0) * stepLot;
    
    if(lot < minLot) lot = minLot;
    if(lot > maxLot) lot = maxLot;
    
    return lot;
}

//+------------------------------------------------------------------+
//| Module 2: Trend Filter (EMA 200)                                 |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    double emaBuffer[];
    ArraySetAsSeries(emaBuffer, true);
    
    // Copy EMA value for Candle Index 1 (Closed Candle)
    if(CopyBuffer(emaHandle, 0, 1, 1, emaBuffer) != 1) return 0;
    
    double emaValue = emaBuffer[0];
    double closePrice = iClose(_Symbol, _Period, 1);
    
    if(closePrice > emaValue) return 1;  // Buy Trend
    if(closePrice < emaValue) return -1; // Sell Trend
    
    return 0; // No Trend
}

//+------------------------------------------------------------------+
//| Module 3: Detect Supply & Demand Zones                           |
//+------------------------------------------------------------------+
void DetectSupplyDemandZones()
{
    // Look for Swing High/Low patterns on closed candles
    int lookback = 20;
    
    // Check for Demand Zone (Drop-Base-Drop pattern reversed or Swing Low)
    for(int i = 5; i < lookback; i++)
    {
        double lowCurr = iLow(_Symbol, _Period, i);
        double lowPrev = iLow(_Symbol, _Period, i+1);
        double lowNext = iLow(_Symbol, _Period, i-1);
        
        // Identify Swing Low
        if(lowCurr < lowPrev && lowCurr < lowNext)
        {
            // Check Base formation (Candle i+1 has small body)
            double baseHigh = MathMax(iOpen(_Symbol, _Period, i+1), iClose(_Symbol, _Period, i+1));
            double baseLow = MathMin(iOpen(_Symbol, _Period, i+1), iClose(_Symbol, _Period, i+1));
            double baseBody = MathAbs(baseHigh - baseLow);
            
            // FIXED: Manual ATR Calculation replacing iATR
            double avgRange = 0;
            for(int j=1; j<=14; j++) 
            {
                avgRange += (iHigh(_Symbol, _Period, j) - iLow(_Symbol, _Period, j));
            }
            avgRange /= 14.0;
            
            // Validasi: Base harus lebih kecil dari setengah rata-rata pergerakan
            if(baseBody < (avgRange * 0.5))
            {
                // Found Demand Zone
                zoneLowerBound = lowCurr - (10 * _Point);
                zoneUpperBound = baseHigh + (10 * _Point);
                zoneIsActive = true;
                
                DrawZone(zoneName, zoneUpperBound, zoneLowerBound, ColorDemand);
                Print("Demand Zone Detected: ", zoneLowerBound, " - ", zoneUpperBound);
                return;
            }
        }
    }
    
    // Check for Supply Zone (Swing High)
    for(int i = 5; i < lookback; i++)
    {
        double highCurr = iHigh(_Symbol, _Period, i);
        double highPrev = iHigh(_Symbol, _Period, i+1);
        double highNext = iHigh(_Symbol, _Period, i-1);
        
        if(highCurr > highPrev && highCurr > highNext)
        {
            double baseLow = MathMin(iOpen(_Symbol, _Period, i+1), iClose(_Symbol, _Period, i+1));
            double baseHigh = MathMax(iOpen(_Symbol, _Period, i+1), iClose(_Symbol, _Period, i+1));
            double baseBody = MathAbs(baseHigh - baseLow);
            
            // FIXED: Manual ATR Calculation
            double avgRange = 0;
            for(int j=1; j<=14; j++) 
            {
                avgRange += (iHigh(_Symbol, _Period, j) - iLow(_Symbol, _Period, j));
            }
            avgRange /= 14.0;
            
            if(baseBody < (avgRange * 0.5))
            {
                // Found Supply Zone
                zoneUpperBound = highCurr + (10 * _Point);
                zoneLowerBound = baseLow - (10 * _Point);
                zoneIsActive = true;
                
                DrawZone(zoneName, zoneUpperBound, zoneLowerBound, ColorSupply);
                Print("Supply Zone Detected: ", zoneLowerBound, " - ", zoneUpperBound);
                return;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Module 4: Zone Visualization                                     |
//+------------------------------------------------------------------+
void DrawZone(string name, double upper, double lower, color clr)
{
    // Delete existing first
    ObjectDelete(0, name);
    
    // Create Rectangle
    datetime timeStart = iTime(_Symbol, _Period, 10);
    datetime timeEnd = iTime(_Symbol, _Period, 0) + PeriodSeconds() * 5;
    
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, timeStart, upper, timeEnd, lower))
    {
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Module 5: Zone Mitigation (Cleanup)                              |
//+------------------------------------------------------------------+
void CheckZoneMitigation(double ask, double bid)
{
    bool mitigated = false;
    double closePrice = iClose(_Symbol, _Period, 1);
    
    if(zoneLowerBound > 0 && zoneUpperBound > 0)
    {
        if(closePrice < zoneLowerBound || closePrice > zoneUpperBound)
        {
            mitigated = true;
        }
    }
    
    if(mitigated)
    {
        ObjectDelete(0, zoneName);
        zoneUpperBound = 0;
        zoneLowerBound = 0;
        zoneIsActive = false;
        Print("Zone Mitigated/Broken. Resetting...");
    }
}

//+------------------------------------------------------------------+
//| Module 6: Rejection Logic (Mathematical Ratios)                  |
//+------------------------------------------------------------------+
bool IsPinbarRejection(int mode)
{
    int idx = 1;
    double open = iOpen(_Symbol, _Period, idx);
    double close = iClose(_Symbol, _Period, idx);
    double high = iHigh(_Symbol, _Period, idx);
    double low = iLow(_Symbol, _Period, idx);
    
    double bodySize = MathAbs(open - close);
    double upperWick = high - MathMax(open, close);
    double lowerWick = MathMin(open, close) - low;
    
    if(bodySize == 0) return false;
    
    bool isBuyRejection = false;
    bool isSellRejection = false;
    
    if(lowerWick >= (2.5 * bodySize) && upperWick <= (0.5 * bodySize))
        isBuyRejection = true;
        
    if(upperWick >= (2.5 * bodySize) && lowerWick <= (0.5 * bodySize))
        isSellRejection = true;
    
    bool inZone = false;
    if(zoneIsActive)
    {
        if(mode == 1 && isBuyRejection)
        {
            if(low <= zoneUpperBound && low >= (zoneLowerBound - 20*_Point)) inZone = true;
        }
        else if(mode == -1 && isSellRejection)
        {
            if(high >= zoneLowerBound && high <= (zoneUpperBound + 20*_Point)) inZone = true;
        }
    }
    
    if(mode == 1) return (isBuyRejection && inZone);
    if(mode == -1) return (isSellRejection && inZone);
    
    return false;
}

//+------------------------------------------------------------------+
//| Module 7: Confirmation Logic                                     |
//+------------------------------------------------------------------+
bool IsConfirmation(int mode)
{
    int idx = 1;
    double highRej = iHigh(_Symbol, _Period, idx);
    double lowRej = iLow(_Symbol, _Period, idx);
    
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if(mode == 1)
    {
        return (ask > highRej);
    }
    else if(mode == -1)
    {
        return (bid < lowRej);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Module 8: Execute Buy Order                                      |
//+------------------------------------------------------------------+
void ExecuteBuyOrder(double ask, double bid)
{
    double sl = zoneLowerBound - (30 * _Point);
    double tp = ask + ((ask - sl) * 1.5);
    
    double slPoints = (ask - sl) / _Point;
    double lot = CalculateDynamicLot(slPoints);
    
    if(lot <= 0) 
    {
        Print("Invalid Lot size calculated. Aborting Buy.");
        return;
    }
    
    ObjectDelete(0, zoneName);
    zoneIsActive = false;
    zoneUpperBound = 0;
    zoneLowerBound = 0;
    
    if(trade.Buy(lot, _Symbol, ask, sl, tp, "RX Robo Buy"))
    {
        Print("BUY Executed: Lot=", lot, " SL=", sl, " TP=", tp);
    }
    else
    {
        Print("BUY Failed: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Module 9: Execute Sell Order                                     |
//+------------------------------------------------------------------+
void ExecuteSellOrder(double ask, double bid)
{
    double sl = zoneUpperBound + (30 * _Point);
    double tp = bid - ((sl - bid) * 1.5);
    
    double slPoints = (sl - bid) / _Point;
    double lot = CalculateDynamicLot(slPoints);
    
    if(lot <= 0)
    {
        Print("Invalid Lot size calculated. Aborting Sell.");
        return;
    }
    
    ObjectDelete(0, zoneName);
    zoneIsActive = false;
    zoneUpperBound = 0;
    zoneLowerBound = 0;
    
    if(trade.Sell(lot, _Symbol, bid, sl, tp, "RX Robo Sell"))
    {
        Print("SELL Executed: Lot=", lot, " SL=", sl, " TP=", tp);
    }
    else
    {
        Print("SELL Failed: ", GetLastError());
    }
}
