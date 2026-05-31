# ChatGPT MT5 Trading Signal System

Use ChatGPT as a trading signal layer for MT5.

This project demonstrates a simple architecture:

```text
MT5 Expert Advisor -> Python FastAPI -> ChatGPT / OpenAI API
        ^                                      |
        |---------- structured JSON signal ----|
```

The key design principle is:

```text
ChatGPT gives the signal.
MT5 keeps risk control and order execution.
```

ChatGPT does **not** connect to MT5 directly and does **not** place orders. MT5 collects market data, sends it to the local Python service, receives a structured signal, and then decides what to do.

## Project Files

```text
MT5_AiSignalClient.mq5   MT5 Expert Advisor for collecting market data and calling FastAPI
mt5_ai_server.py         Python FastAPI server that calls OpenAI / ChatGPT
start_server.bat         Starts the local FastAPI server
end_server.bat           Stops the FastAPI server on port 8000
```

## Architecture

### MT5 Expert Advisor

`MT5_AiSignalClient.mq5` runs inside MT5.

It is responsible for:

- Reading current market price
- Reading spread
- Calculating technical indicators
- Building a JSON market snapshot
- Sending the data to FastAPI through `WebRequest()`
- Receiving `BUY`, `SELL`, or `HOLD`
- Applying MT5-side risk checks
- Optionally placing orders

By default, live trading is disabled:

```mql5
input bool InpEnableTrading = false;
```

Keep this disabled while testing.

### Python FastAPI

`mt5_ai_server.py` runs locally on your PC.

It is responsible for:

- Providing the `/signal` HTTP endpoint
- Receiving JSON data from MT5
- Validating the input data
- Calling the OpenAI API
- Asking ChatGPT to return a strict JSON signal
- Returning the result to MT5

Default endpoint:

```text
http://127.0.0.1:8000/signal
```

### ChatGPT / OpenAI

ChatGPT is used as a signal filter.

It receives structured market data and returns:

```json
{
  "signal": "BUY",
  "confidence": 0.72,
  "entry_type": "market",
  "stop_loss_pips": 20,
  "take_profit_pips": 35,
  "reason": "Trend and momentum conditions support a long signal."
}
```

The output is designed to be easy for MT5 to parse.

## Environment Setup

This project assumes you are using Windows, MT5, and Anaconda.

### 1. Create a Python Environment

Open Anaconda Prompt:

```bash
conda create -n mt5-ai python=3.11
conda activate mt5-ai
```

### 2. Install Dependencies

```bash
pip install fastapi uvicorn pydantic openai
```

### 3. Set OpenAI API Key

Temporary setting for the current terminal:

```bat
set OPENAI_API_KEY=your_openai_api_key
```

Recommended permanent Windows setting:

```bat
setx OPENAI_API_KEY "your_openai_api_key"
```

After using `setx`, close and reopen the terminal.

Optional model setting:

```bat
setx OPENAI_MODEL "gpt-5.2"
```

## Start the FastAPI Server

You can start the server by double-clicking:

```text
start_server.bat
```

Or run manually:

```bash
cd "C:\path\to\your\project"
uvicorn mt5_ai_server:app --host 127.0.0.1 --port 8000 --reload
```

Open this page to confirm the server is running:

```text
http://127.0.0.1:8000
```

FastAPI test page:

```text
http://127.0.0.1:8000/docs
```

## Stop the FastAPI Server

Double-click:

```text
end_server.bat
```

This stops the process listening on port `8000`.

## Test the API

Open:

```text
http://127.0.0.1:8000/docs
```

Use `POST /signal` with sample data:

```json
{
  "symbol": "USDJPY",
  "timeframe": "M15",
  "price": 157.25,
  "spread_points": 12,
  "ema20": 157.12,
  "ema50": 156.85,
  "ema200": 156.2,
  "rsi14": 61,
  "atr14": 0.18,
  "multi_timeframe_trend": {
    "m15": {"direction": "up"},
    "h1": {"direction": "up"},
    "h4": {"direction": "neutral"}
  },
  "momentum": {
    "rsi14": 61,
    "macd_histogram": 0.035,
    "adx14": 28
  },
  "volatility": {
    "atr14": 0.18,
    "atr_state": "normal"
  },
  "price_structure": {
    "higher_high": true,
    "higher_low": true
  },
  "key_levels": {
    "today_high": 157.8,
    "today_low": 156.9,
    "quarter_high": 160.2,
    "quarter_low": 151.4,
    "year_high": 162.0,
    "year_low": 140.3
  }
}
```

Expected response:

```json
{
  "symbol": "USDJPY",
  "timeframe": "M15",
  "signal": "BUY",
  "confidence": 0.7,
  "entry_type": "market",
  "stop_loss_pips": 20,
  "take_profit_pips": 35,
  "reason": "Short explanation from ChatGPT.",
  "created_at": "2026-05-31T00:00:00+00:00"
}
```

## MT5 Setup

### 1. Copy the Expert Advisor

In MT5:

```text
File -> Open Data Folder
```

Copy:

```text
MT5_AiSignalClient.mq5
```

to:

```text
MQL5\Experts
```

Then open it in MetaEditor and compile.

### 2. Allow WebRequest

In MT5:

```text
Tools -> Options -> Expert Advisors
```

Enable:

```text
Allow WebRequest for listed URL
```

Add:

```text
http://127.0.0.1:8000
```

### 3. Attach EA to Chart

Attach the EA to your target chart.

If your broker uses a symbol suffix, such as:

```text
USDJPY-
USDJPY.m
USDJPYpro
```

leave `InpSymbol` empty. The EA will use the current chart symbol automatically.

## Signal Frequency

The EA calls FastAPI every 15 minutes by default:

```mql5
input int InpTimerSeconds = 900;
```

This matches an M15 trading workflow.

## Safety Notes

This project is a technical prototype, not financial advice.

Important safety ideas:

- Test on a demo account first
- Keep `InpEnableTrading = false` while testing
- Do not let ChatGPT directly place orders
- Keep final risk control inside MT5
- Add spread, drawdown, lot size, and position limits
- Log every signal and every trade decision
- Backtest and forward-test before any live use

## Design Philosophy

The purpose of this project is not to make ChatGPT a complete trading system.

The better design is modular:

```text
Market data -> FastAPI -> ChatGPT signal -> MT5 risk control -> MT5 execution
```

This pattern can be extended beyond FX trading. The same idea can be applied to stocks, indices, crypto, or other markets, as long as the market data is converted into a structured input and the execution layer remains controlled by a deterministic trading program.

## Disclaimer

Automated trading involves substantial risk. ChatGPT can produce incorrect or unstable signals. This repository is for educational and experimental purposes only. Use at your own risk.
