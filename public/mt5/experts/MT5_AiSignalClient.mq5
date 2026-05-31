#property strict

input string InpServerUrl = "http://127.0.0.1:8000/signal";
input string InpSymbol = "";
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M15;
input int InpTimerSeconds = 900;
input int InpRequestTimeoutMs = 5000;

input int InpStructureLookback = 20;
input int InpQuarterLookbackDays = 66;
input int InpYearLookbackDays = 260;

input bool InpEnableTrading = false;
input long InpMagicNumber = 26052801;
input double InpBaseLots = 0.01;
input double InpLotMultiplier = 1.0;
input int InpMaxPositionsPerSide = 5;
input double InpMaxTotalLots = 0.10;
input double InpGridStepPips = 15.0;
input double InpDefaultTakeProfitPips = 20.0;
input double InpDefaultStopLossPips = 0.0;
input double InpMinConfidence = 0.65;
input int InpMaxSpreadPoints = 25;
input double InpMaxDrawdownPercent = 30.0;
input int InpSlippagePoints = 10;

string tradeSymbol = "";

int ema20Handle = INVALID_HANDLE;
int ema50Handle = INVALID_HANDLE;
int ema200Handle = INVALID_HANDLE;
int rsi14Handle = INVALID_HANDLE;
int atr14Handle = INVALID_HANDLE;
int macdHandle = INVALID_HANDLE;
int adx14Handle = INVALID_HANDLE;
int cci14Handle = INVALID_HANDLE;
int stochHandle = INVALID_HANDLE;

int ema20M15Handle = INVALID_HANDLE;
int ema50M15Handle = INVALID_HANDLE;
int ema200M15Handle = INVALID_HANDLE;
int ema20H1Handle = INVALID_HANDLE;
int ema50H1Handle = INVALID_HANDLE;
int ema200H1Handle = INVALID_HANDLE;
int ema20H4Handle = INVALID_HANDLE;
int ema50H4Handle = INVALID_HANDLE;
int ema200H4Handle = INVALID_HANDLE;


int OnInit()
{
   tradeSymbol = InpSymbol;
   if(tradeSymbol == "")
      tradeSymbol = _Symbol;

   if(!SymbolSelect(tradeSymbol, true))
   {
      Print("Failed to select symbol: ", tradeSymbol);
      return INIT_FAILED;
   }

   ema20Handle = iMA(tradeSymbol, InpTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle = iMA(tradeSymbol, InpTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(tradeSymbol, InpTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
   rsi14Handle = iRSI(tradeSymbol, InpTimeframe, 14, PRICE_CLOSE);
   atr14Handle = iATR(tradeSymbol, InpTimeframe, 14);
   macdHandle = iMACD(tradeSymbol, InpTimeframe, 12, 26, 9, PRICE_CLOSE);
   adx14Handle = iADX(tradeSymbol, InpTimeframe, 14);
   cci14Handle = iCCI(tradeSymbol, InpTimeframe, 14, PRICE_TYPICAL);
   stochHandle = iStochastic(tradeSymbol, InpTimeframe, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

   ema20M15Handle = iMA(tradeSymbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50M15Handle = iMA(tradeSymbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200M15Handle = iMA(tradeSymbol, PERIOD_M15, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema20H1Handle = iMA(tradeSymbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50H1Handle = iMA(tradeSymbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200H1Handle = iMA(tradeSymbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema20H4Handle = iMA(tradeSymbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50H4Handle = iMA(tradeSymbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema200H4Handle = iMA(tradeSymbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE ||
      ema200Handle == INVALID_HANDLE || rsi14Handle == INVALID_HANDLE ||
      atr14Handle == INVALID_HANDLE || macdHandle == INVALID_HANDLE ||
      adx14Handle == INVALID_HANDLE || cci14Handle == INVALID_HANDLE ||
      stochHandle == INVALID_HANDLE || ema20M15Handle == INVALID_HANDLE ||
      ema50M15Handle == INVALID_HANDLE || ema200M15Handle == INVALID_HANDLE ||
      ema20H1Handle == INVALID_HANDLE || ema50H1Handle == INVALID_HANDLE ||
      ema200H1Handle == INVALID_HANDLE || ema20H4Handle == INVALID_HANDLE ||
      ema50H4Handle == INVALID_HANDLE || ema200H4Handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
   }

   EventSetTimer(InpTimerSeconds);
   Print("MT5 AI Signal Client started for ", tradeSymbol, " ", TimeframeToString(InpTimeframe));
   return INIT_SUCCEEDED;
}


void OnDeinit(const int reason)
{
   EventKillTimer();

   ReleaseHandle(ema20Handle);
   ReleaseHandle(ema50Handle);
   ReleaseHandle(ema200Handle);
   ReleaseHandle(rsi14Handle);
   ReleaseHandle(atr14Handle);
   ReleaseHandle(macdHandle);
   ReleaseHandle(adx14Handle);
   ReleaseHandle(cci14Handle);
   ReleaseHandle(stochHandle);
   ReleaseHandle(ema20M15Handle);
   ReleaseHandle(ema50M15Handle);
   ReleaseHandle(ema200M15Handle);
   ReleaseHandle(ema20H1Handle);
   ReleaseHandle(ema50H1Handle);
   ReleaseHandle(ema200H1Handle);
   ReleaseHandle(ema20H4Handle);
   ReleaseHandle(ema50H4Handle);
   ReleaseHandle(ema200H4Handle);
}


void OnTimer()
{
   SendSignalRequest();
}


void OnTick()
{
}


void SendSignalRequest()
{
   double ema20;
   double ema50;
   double ema200;
   double rsi14;
   double atr14;
   double macdMain;
   double macdSignal;
   double adx14;
   double plusDi;
   double minusDi;
   double cci14;
   double stochK;
   double stochD;

   if(!ReadLatestValue(ema20Handle, 0, ema20) ||
      !ReadLatestValue(ema50Handle, 0, ema50) ||
      !ReadLatestValue(ema200Handle, 0, ema200) ||
      !ReadLatestValue(rsi14Handle, 0, rsi14) ||
      !ReadLatestValue(atr14Handle, 0, atr14) ||
      !ReadLatestValue(macdHandle, 0, macdMain) ||
      !ReadLatestValue(macdHandle, 1, macdSignal) ||
      !ReadLatestValue(adx14Handle, 0, adx14) ||
      !ReadLatestValue(adx14Handle, 1, plusDi) ||
      !ReadLatestValue(adx14Handle, 2, minusDi) ||
      !ReadLatestValue(cci14Handle, 0, cci14) ||
      !ReadLatestValue(stochHandle, 0, stochK) ||
      !ReadLatestValue(stochHandle, 1, stochD))
   {
      Print("Waiting for indicator data...");
      return;
   }

   double price = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   long spreadPoints = SymbolInfoInteger(tradeSymbol, SYMBOL_SPREAD);
   double macdHistogram = macdMain - macdSignal;
   double atrAverage = AverageIndicatorValue(atr14Handle, 0, 50);

   string body = "{";
   body += JsonPairString("symbol", tradeSymbol) + ",";
   body += JsonPairString("timeframe", TimeframeToString(InpTimeframe)) + ",";
   body += JsonPairNumber("price", price, DigitsForSymbol(tradeSymbol)) + ",";
   body += JsonPairNumber("spread_points", (double)spreadPoints, 0) + ",";
   body += JsonPairNumber("ema20", ema20, DigitsForSymbol(tradeSymbol)) + ",";
   body += JsonPairNumber("ema50", ema50, DigitsForSymbol(tradeSymbol)) + ",";
   body += JsonPairNumber("ema200", ema200, DigitsForSymbol(tradeSymbol)) + ",";
   body += JsonPairNumber("rsi14", rsi14, 2) + ",";
   body += JsonPairNumber("atr14", atr14, DigitsForSymbol(tradeSymbol)) + ",";
   body += "\"multi_timeframe_trend\":" + BuildMultiTimeframeTrendJson(price) + ",";
   body += "\"momentum\":" + BuildMomentumJson(rsi14, macdMain, macdSignal, macdHistogram, adx14, plusDi, minusDi, cci14, stochK, stochD) + ",";
   body += "\"volatility\":" + BuildVolatilityJson(atr14, atrAverage) + ",";
   body += "\"price_structure\":" + BuildPriceStructureJson(price) + ",";
   body += "\"key_levels\":" + BuildKeyLevelsJson(price);
   body += "}";

   char postData[];
   int bytes = StringToCharArray(body, postData, 0, WHOLE_ARRAY, CP_UTF8);
   if(bytes > 0)
      ArrayResize(postData, bytes - 1);

   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\n";

   ResetLastError();
   int statusCode = WebRequest(
      "POST",
      InpServerUrl,
      headers,
      InpRequestTimeoutMs,
      postData,
      result,
      resultHeaders
   );

   if(statusCode == -1)
   {
      Print("WebRequest failed. Error: ", GetLastError(),
            ". Add this URL in MT5: Tools > Options > Expert Advisors > Allow WebRequest: http://127.0.0.1:8000");
      return;
   }

   string response = CharArrayToString(result, 0, -1, CP_UTF8);

   if(statusCode < 200 || statusCode >= 300)
   {
      Print("Server returned HTTP ", statusCode, ". Response: ", response);
      return;
   }

   string signal = ExtractJsonString(response, "signal");
   string entryType = ExtractJsonString(response, "entry_type");
   string reason = ExtractJsonString(response, "reason");
   double confidence = ExtractJsonNumber(response, "confidence");
   double stopLossPips = ExtractJsonNumber(response, "stop_loss_pips");
   double takeProfitPips = ExtractJsonNumber(response, "take_profit_pips");

   Print("AI Signal | ",
         tradeSymbol, " ", TimeframeToString(InpTimeframe),
         " | signal=", signal,
         " | confidence=", DoubleToString(confidence, 2),
         " | entry=", entryType,
         " | SL pips=", DoubleToString(stopLossPips, 1),
         " | TP pips=", DoubleToString(takeProfitPips, 1),
         " | reason=", reason);

   HandleTradingSignal(signal, confidence, entryType, stopLossPips, takeProfitPips);
}


string BuildMultiTimeframeTrendJson(const double price)
{
   string json = "{";
   json += "\"m15\":" + BuildTrendForTimeframeJson("M15", PERIOD_M15, ema20M15Handle, ema50M15Handle, ema200M15Handle, price) + ",";
   json += "\"h1\":" + BuildTrendForTimeframeJson("H1", PERIOD_H1, ema20H1Handle, ema50H1Handle, ema200H1Handle, price) + ",";
   json += "\"h4\":" + BuildTrendForTimeframeJson("H4", PERIOD_H4, ema20H4Handle, ema50H4Handle, ema200H4Handle, price);
   json += "}";
   return json;
}


string BuildTrendForTimeframeJson(
   const string label,
   const ENUM_TIMEFRAMES timeframe,
   const int ema20,
   const int ema50,
   const int ema200,
   const double currentPrice
)
{
   double e20 = 0.0;
   double e50 = 0.0;
   double e200 = 0.0;

   ReadLatestValue(ema20, 0, e20);
   ReadLatestValue(ema50, 0, e50);
   ReadLatestValue(ema200, 0, e200);

   string direction = "neutral";
   if(currentPrice > e20 && e20 > e50 && e50 > e200)
      direction = "up";
   else if(currentPrice < e20 && e20 < e50 && e50 < e200)
      direction = "down";

   string json = "{";
   json += JsonPairString("timeframe", label) + ",";
   json += JsonPairString("direction", direction) + ",";
   json += JsonPairNumber("ema20", e20, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("ema50", e50, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("ema200", e200, DigitsForSymbol(tradeSymbol));
   json += "}";
   return json;
}


string BuildMomentumJson(
   const double rsi14,
   const double macdMain,
   const double macdSignal,
   const double macdHistogram,
   const double adx14,
   const double plusDi,
   const double minusDi,
   const double cci14,
   const double stochK,
   const double stochD
)
{
   string json = "{";
   json += JsonPairNumber("rsi14", rsi14, 2) + ",";
   json += JsonPairNumber("macd_main", macdMain, 6) + ",";
   json += JsonPairNumber("macd_signal", macdSignal, 6) + ",";
   json += JsonPairNumber("macd_histogram", macdHistogram, 6) + ",";
   json += JsonPairNumber("adx14", adx14, 2) + ",";
   json += JsonPairNumber("plus_di", plusDi, 2) + ",";
   json += JsonPairNumber("minus_di", minusDi, 2) + ",";
   json += JsonPairNumber("cci14", cci14, 2) + ",";
   json += JsonPairNumber("stochastic_k", stochK, 2) + ",";
   json += JsonPairNumber("stochastic_d", stochD, 2);
   json += "}";
   return json;
}


string BuildVolatilityJson(const double atr14, const double atrAverage)
{
   string state = "normal";
   if(atrAverage > 0.0)
   {
      if(atr14 > atrAverage * 1.5)
         state = "high";
      else if(atr14 < atrAverage * 0.7)
         state = "low";
   }

   string json = "{";
   json += JsonPairNumber("atr14", atr14, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("atr50_average", atrAverage, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairString("atr_state", state) + ",";
   json += JsonPairNumber("current_candle_body_pips", CurrentCandleBodyPips(), 1);
   json += "}";
   return json;
}


string BuildPriceStructureJson(const double price)
{
   int lookback = MathMax(InpStructureLookback, 5);
   double recentHigh = HighestHigh(PERIOD_CURRENT, lookback, 1);
   double recentLow = LowestLow(PERIOD_CURRENT, lookback, 1);
   double previousHigh = HighestHigh(PERIOD_CURRENT, lookback, lookback + 1);
   double previousLow = LowestLow(PERIOD_CURRENT, lookback, lookback + 1);

   bool higherHigh = (recentHigh > previousHigh && previousHigh > 0.0);
   bool higherLow = (recentLow > previousLow && previousLow > 0.0);
   bool lowerHigh = (recentHigh < previousHigh && previousHigh > 0.0);
   bool lowerLow = (recentLow < previousLow && previousLow > 0.0);
   bool nearRangeHigh = (recentHigh > 0.0 && MathAbs(price - recentHigh) <= 5.0 * PipSize(tradeSymbol));
   bool nearRangeLow = (recentLow > 0.0 && MathAbs(price - recentLow) <= 5.0 * PipSize(tradeSymbol));

   string json = "{";
   json += JsonPairNumber("lookback_bars", (double)lookback, 0) + ",";
   json += JsonPairNumber("recent_high", recentHigh, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("recent_low", recentLow, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairBool("higher_high", higherHigh) + ",";
   json += JsonPairBool("higher_low", higherLow) + ",";
   json += JsonPairBool("lower_high", lowerHigh) + ",";
   json += JsonPairBool("lower_low", lowerLow) + ",";
   json += JsonPairBool("near_recent_high", nearRangeHigh) + ",";
   json += JsonPairBool("near_recent_low", nearRangeLow);
   json += "}";
   return json;
}


string BuildKeyLevelsJson(const double price)
{
   double todayHigh = iHigh(tradeSymbol, PERIOD_D1, 0);
   double todayLow = iLow(tradeSymbol, PERIOD_D1, 0);
   double yesterdayHigh = iHigh(tradeSymbol, PERIOD_D1, 1);
   double yesterdayLow = iLow(tradeSymbol, PERIOD_D1, 1);
   double quarterHigh = HighestHigh(PERIOD_D1, InpQuarterLookbackDays, 1);
   double quarterLow = LowestLow(PERIOD_D1, InpQuarterLookbackDays, 1);
   double yearHigh = HighestHigh(PERIOD_D1, InpYearLookbackDays, 1);
   double yearLow = LowestLow(PERIOD_D1, InpYearLookbackDays, 1);

   string json = "{";
   json += JsonPairNumber("today_high", todayHigh, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("today_low", todayLow, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("yesterday_high", yesterdayHigh, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("yesterday_low", yesterdayLow, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("quarter_high", quarterHigh, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("quarter_low", quarterLow, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("year_high", yearHigh, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("year_low", yearLow, DigitsForSymbol(tradeSymbol)) + ",";
   json += JsonPairNumber("distance_to_quarter_high_pips", DistancePips(price, quarterHigh), 1) + ",";
   json += JsonPairNumber("distance_to_quarter_low_pips", DistancePips(price, quarterLow), 1) + ",";
   json += JsonPairNumber("distance_to_year_high_pips", DistancePips(price, yearHigh), 1) + ",";
   json += JsonPairNumber("distance_to_year_low_pips", DistancePips(price, yearLow), 1);
   json += "}";
   return json;
}


bool ReadLatestValue(const int handle, const int bufferNo, double &value)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(handle, bufferNo, 0, 1, buffer) != 1)
      return false;

   value = buffer[0];
   return true;
}


double AverageIndicatorValue(const int handle, const int bufferNo, const int count)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(handle, bufferNo, 0, count, buffer);
   if(copied <= 0)
      return 0.0;

   double sum = 0.0;
   for(int i = 0; i < copied; i++)
      sum += buffer[i];

   return sum / copied;
}


double HighestHigh(const ENUM_TIMEFRAMES timeframe, const int count, const int startShift)
{
   int bars = Bars(tradeSymbol, timeframe);
   if(bars <= startShift)
      return 0.0;

   int safeCount = MathMin(count, bars - startShift);
   int index = iHighest(tradeSymbol, timeframe, MODE_HIGH, safeCount, startShift);
   if(index < 0)
      return 0.0;

   return iHigh(tradeSymbol, timeframe, index);
}


double LowestLow(const ENUM_TIMEFRAMES timeframe, const int count, const int startShift)
{
   int bars = Bars(tradeSymbol, timeframe);
   if(bars <= startShift)
      return 0.0;

   int safeCount = MathMin(count, bars - startShift);
   int index = iLowest(tradeSymbol, timeframe, MODE_LOW, safeCount, startShift);
   if(index < 0)
      return 0.0;

   return iLow(tradeSymbol, timeframe, index);
}


double CurrentCandleBodyPips()
{
   double open = iOpen(tradeSymbol, InpTimeframe, 0);
   double close = iClose(tradeSymbol, InpTimeframe, 0);
   return MathAbs(close - open) / PipSize(tradeSymbol);
}


double DistancePips(const double price, const double level)
{
   if(level <= 0.0)
      return 0.0;

   return (level - price) / PipSize(tradeSymbol);
}


string JsonPairString(const string key, const string value)
{
   return "\"" + key + "\":\"" + JsonEscape(value) + "\"";
}


string JsonPairNumber(const string key, const double value, const int digits)
{
   return "\"" + key + "\":" + DoubleToString(value, digits);
}


string JsonPairBool(const string key, const bool value)
{
   return "\"" + key + "\":" + (value ? "true" : "false");
}


string JsonEscape(string value)
{
   StringReplace(value, "\\", "\\\\");
   StringReplace(value, "\"", "\\\"");
   return value;
}


void ReleaseHandle(int &handle)
{
   if(handle != INVALID_HANDLE)
   {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
   }
}


void HandleTradingSignal(
   const string signal,
   const double confidence,
   const string entryType,
   const double stopLossPips,
   const double takeProfitPips
)
{
   if(!InpEnableTrading)
   {
      Print("Trading disabled. Signal was logged only.");
      return;
   }

   if(signal != "BUY" && signal != "SELL")
      return;

   if(entryType != "market")
      return;

   if(confidence < InpMinConfidence)
   {
      Print("Signal confidence too low: ", DoubleToString(confidence, 2));
      return;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("MT5 trading is not allowed.");
      return;
   }

   if(!CheckSpread())
      return;

   if(!CheckDrawdown())
      return;

   ENUM_ORDER_TYPE orderType = (signal == "BUY" ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   ENUM_POSITION_TYPE positionType = (signal == "BUY" ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   ENUM_POSITION_TYPE oppositeType = (signal == "BUY" ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);

   int oppositeCount = CountPositions(oppositeType);
   if(oppositeCount > 0)
   {
      Print("Opposite position exists. Skip new ", signal, " entry.");
      return;
   }

   int currentCount = CountPositions(positionType);
   if(currentCount >= InpMaxPositionsPerSide)
   {
      Print("Max ", signal, " positions reached: ", currentCount);
      return;
   }

   double totalLots = GetTotalLotsByMagic();
   if(totalLots >= InpMaxTotalLots)
   {
      Print("Max total lots reached: ", DoubleToString(totalLots, 2));
      return;
   }

   if(currentCount > 0 && !ShouldAddGridPosition(positionType))
      return;

   double rawLots = InpBaseLots * MathPow(InpLotMultiplier, currentCount);
   double lots = CalcSafeLots(rawLots, totalLots);
   if(lots <= 0)
   {
      Print("No lot capacity left.");
      return;
   }

   double tpPips = takeProfitPips > 0 ? takeProfitPips : InpDefaultTakeProfitPips;
   double slPips = stopLossPips > 0 ? stopLossPips : InpDefaultStopLossPips;
   OpenMarketPosition(orderType, lots, slPips, tpPips);
}


bool CheckSpread()
{
   long spreadPoints = SymbolInfoInteger(tradeSymbol, SYMBOL_SPREAD);
   if(spreadPoints > InpMaxSpreadPoints)
   {
      Print("Spread too wide: ", spreadPoints, " points.");
      return false;
   }
   return true;
}


bool CheckDrawdown()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0)
      return true;

   double drawdown = (balance - equity) / balance * 100.0;
   if(drawdown >= InpMaxDrawdownPercent)
   {
      Print("Drawdown limit reached: ", DoubleToString(drawdown, 2), "%.");
      return false;
   }
   return true;
}


int CountPositions(const ENUM_POSITION_TYPE typeFilter)
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != tradeSymbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == typeFilter)
         count++;
   }

   return count;
}


double GetTotalLotsByMagic()
{
   double totalLots = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != tradeSymbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      totalLots += PositionGetDouble(POSITION_VOLUME);
   }

   return totalLots;
}


bool ShouldAddGridPosition(const ENUM_POSITION_TYPE positionType)
{
   double lastPrice = 0.0;
   datetime lastTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != tradeSymbol)
         continue;

      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != positionType)
         continue;

      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(positionTime >= lastTime)
      {
         lastTime = positionTime;
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      }
   }

   if(lastPrice <= 0)
      return true;

   double bid = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);
   double gridDistance = InpGridStepPips * PipSize(tradeSymbol);

   if(positionType == POSITION_TYPE_BUY)
   {
      if(ask <= lastPrice - gridDistance)
         return true;
   }
   else if(positionType == POSITION_TYPE_SELL)
   {
      if(bid >= lastPrice + gridDistance)
         return true;
   }

   Print("Grid step not reached. Last price=", DoubleToString(lastPrice, DigitsForSymbol(tradeSymbol)));
   return false;
}


double CalcSafeLots(const double rawLots, const double totalLots)
{
   double minLot = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(tradeSymbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0)
      lotStep = 0.01;

   double remainingLots = InpMaxTotalLots - totalLots;
   if(remainingLots < minLot)
      return 0.0;

   double lots = MathMax(rawLots, minLot);
   lots = MathMin(lots, maxLot);
   lots = MathMin(lots, remainingLots);
   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot)
      return 0.0;

   return NormalizeDouble(lots, 2);
}


bool OpenMarketPosition(
   const ENUM_ORDER_TYPE orderType,
   const double lots,
   const double stopLossPips,
   const double takeProfitPips
)
{
   double bid = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);
   double price = (orderType == ORDER_TYPE_BUY ? ask : bid);
   double pip = PipSize(tradeSymbol);
   int digits = DigitsForSymbol(tradeSymbol);

   double sl = 0.0;
   double tp = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      if(stopLossPips > 0)
         sl = NormalizeDouble(price - stopLossPips * pip, digits);
      if(takeProfitPips > 0)
         tp = NormalizeDouble(price + takeProfitPips * pip, digits);
   }
   else
   {
      if(stopLossPips > 0)
         sl = NormalizeDouble(price + stopLossPips * pip, digits);
      if(takeProfitPips > 0)
         tp = NormalizeDouble(price - takeProfitPips * pip, digits);
   }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.symbol = tradeSymbol;
   request.magic = InpMagicNumber;
   request.volume = lots;
   request.type = orderType;
   request.price = NormalizeDouble(price, digits);
   request.sl = sl;
   request.tp = tp;
   request.deviation = InpSlippagePoints;
   request.type_filling = FillMode();
   request.type_time = ORDER_TIME_GTC;
   request.comment = "ai grid";

   ResetLastError();
   bool ok = OrderSend(request, result);
   if(!ok || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
   {
      Print("OrderSend failed. retcode=", result.retcode, " error=", GetLastError(), " comment=", result.comment);
      return false;
   }

   Print("Order opened. type=", EnumToString(orderType),
         " lots=", DoubleToString(lots, 2),
         " price=", DoubleToString(price, digits),
         " sl=", DoubleToString(sl, digits),
         " tp=", DoubleToString(tp, digits));
   return true;
}


ENUM_ORDER_TYPE_FILLING FillMode()
{
   long filling = SymbolInfoInteger(tradeSymbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}


double PipSize(const string symbol)
{
   int digits = DigitsForSymbol(symbol);
   if(digits == 3 || digits == 5)
      return 10.0 * SymbolInfoDouble(symbol, SYMBOL_POINT);

   return SymbolInfoDouble(symbol, SYMBOL_POINT);
}


int DigitsForSymbol(const string symbol)
{
   return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
}


string TimeframeToString(const ENUM_TIMEFRAMES timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return EnumToString(timeframe);
   }
}


string ExtractJsonString(const string json, const string key)
{
   string pattern = "\"" + key + "\":";
   int keyPos = StringFind(json, pattern);
   if(keyPos < 0)
      return "";

   int valueStart = StringFind(json, "\"", keyPos + StringLen(pattern));
   if(valueStart < 0)
      return "";

   int valueEnd = StringFind(json, "\"", valueStart + 1);
   if(valueEnd < 0)
      return "";

   return StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
}


double ExtractJsonNumber(const string json, const string key)
{
   string pattern = "\"" + key + "\":";
   int keyPos = StringFind(json, pattern);
   if(keyPos < 0)
      return 0.0;

   int valueStart = keyPos + StringLen(pattern);
   while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ')
      valueStart++;

   if(StringSubstr(json, valueStart, 4) == "null")
      return 0.0;

   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueEnd);
      if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-')
      {
         valueEnd++;
         continue;
      }
      break;
   }

   string rawValue = StringSubstr(json, valueStart, valueEnd - valueStart);
   return StringToDouble(rawValue);
}
