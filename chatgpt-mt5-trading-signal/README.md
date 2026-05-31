# 如何利用 ChatGPT 实现 MT5 交易信号系统

本项目演示一种基于 **MT5 + Python FastAPI + ChatGPT / OpenAI API** 的交易信号架构。

核心思路是：

```text
MT5 采集行情
  ↓
Python FastAPI 负责桥接
  ↓
ChatGPT 判断交易信号
  ↓
MT5 接收信号并执行风控 / 下单
```

需要特别强调的是：

```text
ChatGPT 只负责给出交易信号。
MT5 负责最终风控和交易执行。
```

ChatGPT 不直接连接 MT5，也不直接下单。它只是交易系统中的“信号判断层”。

## 项目文件

```text
mt5/experts/MT5_AiSignalClient.mq5       MT5 EA，负责采集行情并调用 FastAPI
python/utilities/mt5_ai_server.py        Python FastAPI 服务，负责调用 ChatGPT
README.md                                项目说明文档
```

如果你在本地使用了启动脚本，也可以加入：

```text
start_server.bat                         启动 FastAPI 服务
end_server.bat                           关闭 8000 端口上的 FastAPI 服务
```

## 一、整体架构

整个系统分为三层：

```text
MT5 EA  →  Python FastAPI  →  ChatGPT / OpenAI API
  ↑                                      ↓
  ←────────── 交易信号 JSON ─────────────
```

### 1. MT5 的分工

MT5 是交易终端，也是最终执行交易的地方。

MT5 EA 主要负责：

- 采集当前行情
- 获取价格、点差等信息
- 计算技术指标
- 组装 JSON 请求
- 通过 `WebRequest()` 调用 FastAPI
- 接收 ChatGPT 返回的 `BUY / SELL / HOLD`
- 执行 MT5 端风控
- 根据参数决定是否真实下单

### 2. Python FastAPI 的分工

FastAPI 是 MT5 和 ChatGPT 之间的桥。

它主要负责：

- 提供本地 HTTP 接口
- 接收 MT5 发来的行情 JSON
- 校验输入数据
- 调用 OpenAI API
- 要求 ChatGPT 返回固定 JSON 格式
- 把交易信号返回给 MT5

默认接口地址：

```text
http://127.0.0.1:8000/signal
```

### 3. ChatGPT 的分工

ChatGPT 只负责判断市场方向。

它根据 MT5 提供的结构化行情数据，返回类似下面的结果：

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

字段含义：

- `signal`：交易方向，取值为 `BUY`、`SELL`、`HOLD`
- `confidence`：信号置信度，范围为 0 到 1
- `entry_type`：入场方式，目前主要使用 `market`
- `stop_loss_pips`：建议止损点数
- `take_profit_pips`：建议止盈点数
- `reason`：简短理由

这种设计的好处是：

- ChatGPT 不接触账户权限
- MT5 保留最终交易控制权
- 信号格式固定，便于程序解析
- 后续可以接入不同交易策略
- 可以继续在 MT5 端叠加风控规则

## 二、MT5 端程序逻辑

`MT5_AiSignalClient.mq5` 是 MT5 端 EA。

它的基本流程是：

```text
定时触发
  ↓
读取行情
  ↓
计算指标
  ↓
发送给 FastAPI
  ↓
接收 ChatGPT 信号
  ↓
执行风控过滤
  ↓
决定是否下单
```

### 采集的数据

当前版本会向 FastAPI 发送较完整的市场快照，包括：

- 当前价格
- 当前点差
- EMA20 / EMA50 / EMA200
- RSI14
- ATR14
- 多周期趋势
- 动量指标
- 波动率状态
- 价格结构
- 关键价格位置
- 三个月高低点
- 一年高低点

发送给 FastAPI 的 JSON 大致类似：

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

### 调用频率

EA 默认每 15 分钟调用一次 FastAPI：

```mql5
input int InpTimerSeconds = 900;
```

这比较适合 M15 周期的交易判断。

### 交易开关

默认不真实下单：

```mql5
input bool InpEnableTrading = false;
```

测试阶段建议保持 `false`，只观察日志中的信号。

确认逻辑稳定后，再考虑在模拟账户中打开：

```mql5
InpEnableTrading = true;
```

## 三、FastAPI 的构造与测试

Python 端使用 FastAPI。

如果你已经安装 Anaconda，可以按下面方式准备环境。

### 1. 创建 Python 环境

```bash
conda create -n mt5-ai python=3.11
conda activate mt5-ai
```

### 2. 安装依赖

```bash
pip install fastapi uvicorn pydantic openai
```

依赖说明：

- `fastapi`：创建 HTTP 服务
- `uvicorn`：启动服务
- `pydantic`：校验输入和输出
- `openai`：调用 OpenAI API

### 3. 设置 OpenAI API Key

临时设置方式：

```bat
set OPENAI_API_KEY=你的OpenAI_API_Key
```

这种方式只对当前窗口有效。

更推荐设置为 Windows 永久环境变量：

```bat
setx OPENAI_API_KEY "你的OpenAI_API_Key"
```

设置后关闭当前窗口，重新打开 Anaconda Prompt。

如果需要指定模型：

```bat
setx OPENAI_MODEL "gpt-5.2"
```

### 4. 启动 FastAPI

进入项目目录：

```bash
cd "C:\你的项目目录"
uvicorn mt5_ai_server:app --host 127.0.0.1 --port 8000 --reload
```

如果使用了启动脚本，可以直接双击：

```text
start_server.bat
```

启动后打开：

```text
http://127.0.0.1:8000
```

看到服务运行信息，就说明启动成功。

### 5. 测试接口

FastAPI 自带测试页面：

```text
http://127.0.0.1:8000/docs
```

找到：

```text
POST /signal
```

点击 `Try it out`，填入测试 JSON，就可以直接测试 ChatGPT 信号返回。

## 四、ChatGPT 端程序逻辑

ChatGPT 端的关键不是输出长篇分析，而是返回稳定、可解析的结构化信号。

FastAPI 会要求 ChatGPT 按固定 JSON Schema 返回结果。

例如：

```json
{
  "signal": "HOLD",
  "confidence": 0.58,
  "entry_type": "none",
  "stop_loss_pips": null,
  "take_profit_pips": null,
  "reason": "Trend signals are mixed and price is close to resistance."
}
```

提示词中会明确限制：

```text
你是 MT5 的交易信号过滤器。
你不负责下单。
你只能基于输入数据判断交易方向。
你必须返回符合 JSON Schema 的结果。
不要编造输入中没有提供的市场数据。
```

这样可以避免 ChatGPT 输出难以解析的自然语言内容。

## 五、MT5 配置

### 1. 复制 EA 文件

在 MT5 中：

```text
File -> Open Data Folder
```

把：

```text
MT5_AiSignalClient.mq5
```

复制到：

```text
MQL5\Experts
```

然后用 MetaEditor 打开并编译。

### 2. 允许 WebRequest

在 MT5 中打开：

```text
Tools -> Options -> Expert Advisors
```

勾选：

```text
Allow WebRequest for listed URL
```

添加：

```text
http://127.0.0.1:8000
```

### 3. 挂载 EA

把 EA 挂到目标品种图表上。

如果券商品种带后缀，例如：

```text
USDJPY-
USDJPY.m
USDJPYpro
```

可以让 `InpSymbol` 保持为空，EA 会自动使用当前图表品种。

## 六、安全注意事项

本项目是技术原型，不是投资建议。

自动交易风险很高，务必注意：

- 先在模拟账户测试
- 默认保持 `InpEnableTrading = false`
- 不要让 ChatGPT 直接下单
- 最终风控必须保留在 MT5 端
- 设置最大手数限制
- 设置点差限制
- 设置回撤限制
- 记录每一次信号和交易决策
- 实盘前必须长期回测和模拟盘验证

## 七、扩展方向

这个架构不仅可以用于 FX 交易，也可以扩展到股票、指数、加密货币等市场。

通用模式是：

```text
行情系统采集数据
  ↓
Python 服务整理数据
  ↓
ChatGPT 判断信号
  ↓
交易程序执行风控和下单
```

后续可以继续扩展：

- 接入实时新闻
- 接入财经日历
- 接入宏观数据
- 加入财报摘要
- 加入多周期趋势判断
- 加入回测模块
- 加入交易日志复盘

## 免责声明

本项目仅用于学习和技术研究。自动化交易可能造成亏损，ChatGPT 也可能给出错误信号。请自行承担使用风险。
