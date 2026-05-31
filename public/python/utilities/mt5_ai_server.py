import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, Literal, Optional

from fastapi import FastAPI
from pydantic import BaseModel, ConfigDict, Field

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None


app = FastAPI(title="MT5 AI Signal Server")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5.2")


class MarketData(BaseModel):
    model_config = ConfigDict(extra="allow")

    symbol: str = Field(default="USDJPY", examples=["USDJPY"])
    timeframe: str = Field(..., examples=["M15", "H1"])
    price: float
    ema20: Optional[float] = None
    ema50: Optional[float] = None
    ema200: Optional[float] = None
    rsi14: Optional[float] = None
    atr14: Optional[float] = None
    spread_points: Optional[float] = None
    open_position: Optional[str] = Field(default="none", examples=["none", "BUY", "SELL"])
    multi_timeframe_trend: Optional[Dict[str, Any]] = None
    momentum: Optional[Dict[str, Any]] = None
    volatility: Optional[Dict[str, Any]] = None
    price_structure: Optional[Dict[str, Any]] = None
    key_levels: Optional[Dict[str, Any]] = None


class TradeSignal(BaseModel):
    symbol: str
    timeframe: str
    signal: Literal["BUY", "SELL", "HOLD"]
    confidence: float
    entry_type: Literal["market", "none"]
    stop_loss_pips: Optional[float]
    take_profit_pips: Optional[float]
    reason: str
    created_at: str


SIGNAL_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "signal": {"type": "string", "enum": ["BUY", "SELL", "HOLD"]},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "entry_type": {"type": "string", "enum": ["market", "none"]},
        "stop_loss_pips": {"type": ["number", "null"]},
        "take_profit_pips": {"type": ["number", "null"]},
        "reason": {"type": "string"},
    },
    "required": [
        "signal",
        "confidence",
        "entry_type",
        "stop_loss_pips",
        "take_profit_pips",
        "reason",
    ],
}


@app.get("/")
def health_check():
    return {
        "status": "ok",
        "message": "MT5 AI Signal Server is running",
    }


def create_trade_signal(
    data: MarketData,
    signal: Literal["BUY", "SELL", "HOLD"],
    confidence: float,
    entry_type: Literal["market", "none"],
    stop_loss_pips: Optional[float],
    take_profit_pips: Optional[float],
    reason: str,
) -> TradeSignal:
    if signal == "HOLD":
        entry_type = "none"
        stop_loss_pips = None
        take_profit_pips = None

    return TradeSignal(
        symbol=data.symbol,
        timeframe=data.timeframe,
        signal=signal,
        confidence=confidence,
        entry_type=entry_type,
        stop_loss_pips=stop_loss_pips,
        take_profit_pips=take_profit_pips,
        reason=reason,
        created_at=datetime.now(timezone.utc).isoformat(),
    )


def get_rule_based_signal(data: MarketData) -> TradeSignal:
    signal = "HOLD"
    confidence = 0.5
    reason = "Not enough trend information. Holding position."

    if data.ema20 is not None and data.ema50 is not None:
        if data.price > data.ema20 > data.ema50:
            signal = "BUY"
            confidence = 0.68
            reason = "Price is above EMA20 and EMA20 is above EMA50, suggesting an upward trend."
        elif data.price < data.ema20 < data.ema50:
            signal = "SELL"
            confidence = 0.68
            reason = "Price is below EMA20 and EMA20 is below EMA50, suggesting a downward trend."

    if data.rsi14 is not None:
        if data.rsi14 > 75:
            signal = "HOLD"
            confidence = 0.6
            reason = "RSI is high, so the trend may be overextended. Holding position."
        elif data.rsi14 < 25:
            signal = "HOLD"
            confidence = 0.6
            reason = "RSI is low, so the trend may be overextended. Holding position."

    return create_trade_signal(
        data=data,
        signal=signal,
        confidence=confidence,
        entry_type="market" if signal != "HOLD" else "none",
        stop_loss_pips=20.0 if signal != "HOLD" else None,
        take_profit_pips=35.0 if signal != "HOLD" else None,
        reason=reason,
    )


def get_ai_signal(data: MarketData) -> TradeSignal:
    if OpenAI is None:
        return get_rule_based_signal(data)

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return get_rule_based_signal(data)

    client = OpenAI(api_key=api_key)
    payload = data.model_dump()

    response = client.responses.create(
        model=OPENAI_MODEL,
        instructions=(
            "You are a conservative trading signal filter for MT5. "
            "You do not place trades. You only return JSON that matches the schema. "
            "Focus on market direction using the provided technical signals: "
            "multi-timeframe trend, momentum, volatility, price structure, and key levels. "
            "When trend_inputs or strategy_context are present, use them as the MT5 strategy's "
            "trend-lock decision inputs. "
            "Do not use account state or trade history to decide direction. "
            "Return HOLD when the market direction is unclear, the signals conflict, "
            "price is too close to major support or resistance, volatility is abnormal, "
            "or risk/reward is unattractive. Do not invent missing market data."
        ),
        input=(
            "Analyze this market snapshot and return one trading signal. "
            f"Market data JSON: {json.dumps(payload, ensure_ascii=False)}"
        ),
        text={
            "format": {
                "type": "json_schema",
                "name": "trade_signal",
                "schema": SIGNAL_SCHEMA,
                "strict": True,
            }
        },
    )

    result = json.loads(response.output_text)
    return create_trade_signal(data=data, **result)


@app.post("/signal", response_model=TradeSignal)
def get_signal(data: MarketData):
    return get_ai_signal(data)
