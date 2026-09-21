import { useEffect, useState } from "react";
import {
  ArrowCounterClockwise,
  CaretLeft,
  CaretRight,
  ChartBar,
  DotsThreeVertical,
  Gear,
  Info,
  Minus,
  Pause,
  Play,
  Plus,
  Power,
  SpeakerHigh,
  Timer,
  X,
  XCircle,
} from "@phosphor-icons/react";

function makeValues(count, seed) {
  return Array.from({ length: count }, (_, index) => 18 + ((index * 37 + seed * 17) % 78));
}

function formatWeek(start, end) {
  const startText = `${start.getMonth() + 1}月${start.getDate()}日`;
  const endText = start.getMonth() === end.getMonth() ? `${end.getDate()}日` : `${end.getMonth() + 1}月${end.getDate()}日`;
  return `${startText}至${endText}`;
}

function getStatistics(range, offset) {
  if (range === "D") {
    const date = new Date(2026, 7, 30 + offset);
    return { period: `${date.getMonth() + 1}月${date.getDate()}日 · ${Math.max(4, 19 + offset)}次`, labels: Array.from({ length: 24 }, (_, hour) => [0, 6, 12, 18, 23].includes(hour) ? String(hour) : ""), values: makeValues(24, offset + 24) };
  }
  if (range === "W") {
    const end = new Date(2026, 7, 30 + offset * 7);
    const start = new Date(end); start.setDate(end.getDate() - 6);
    return { period: `${formatWeek(start, end)} · ${Math.max(7, 42 + offset * 5)}次`, labels: ["一", "二", "三", "四", "五", "六", "日"], values: makeValues(7, offset + 7) };
  }
  if (range === "M") {
    const date = new Date(2026, 7 + offset, 1);
    const days = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    return { period: `${date.getFullYear()}年${date.getMonth() + 1}月 · ${Math.max(20, 126 + offset * 7)}次`, labels: Array.from({ length: days }, (_, index) => { const day = index + 1; return day === 1 || day % 5 === 0 || day === days ? String(day) : ""; }), values: makeValues(days, date.getMonth() + 1) };
  }
  const year = 2026 + offset;
  return { period: `${year}年 · ${Math.max(100, 824 + offset * 83)}次`, labels: Array.from({ length: 12 }, (_, month) => String(month + 1)), values: makeValues(12, year) };
}

function Toggle({ checked, onChange, label }) {
  return <button type="button" className={`toggle ${checked ? "is-on" : ""}`} aria-pressed={checked} aria-label={label} onClick={() => onChange(!checked)}><span /></button>;
}

function CycleDots({ cycle, total, breakMode }) {
  return <div className={`cycle-dots ${breakMode ? "on-color" : ""}`} aria-label={`第 ${cycle} 轮，共 ${total} 轮`}>
    {Array.from({ length: total }, (_, index) => <span key={index} className={index < cycle ? "is-complete" : ""} />)}
  </div>;
}

function BackHeader({ title, onBack, action }) {
  return <header className="panel-header"><button className="icon-button" onClick={onBack} aria-label="返回"><CaretLeft size={19} /></button><h2>{title}</h2><div className="header-action">{action}</div></header>;
}

function TimerScreen({ phase, seconds, running, cycle, totalCycles, onToggle, onReset, onMenu, onStatistics, onClose }) {
  const isBreak = phase !== "focus";
  const title = phase === "focus" ? "NanaFlow" : phase === "shortBreak" ? "休息" : "长休息";
  const time = formatTime(seconds);
  return <section className={`timer-screen ${isBreak ? "is-break" : ""}`}>
    <div className="timer-toolbar">
      <button className="toolbar-close" onClick={onClose} aria-label="隐藏窗口"><XCircle size={17} weight="fill" /></button>
      <div className="toolbar-actions">
        <button className="tool-button" onClick={onReset} aria-label="重新开始周期"><ArrowCounterClockwise size={19} /></button>
        <button className="tool-button" onClick={onStatistics} aria-label="统计"><ChartBar size={20} /></button>
        <button className="tool-button" onClick={onMenu} aria-label="菜单"><DotsThreeVertical size={20} weight="bold" /></button>
      </div>
    </div>
    <div className="timer-content">
      <div className="phase-title">{title}</div>
      <div className="time-display" aria-live="polite">{time}</div>
      <CycleDots cycle={cycle} total={totalCycles} breakMode={isBreak} />
      <button className="primary-timer-button" onClick={onToggle} aria-label={running ? "暂停" : "开始"}>{running ? <Pause size={22} /> : <Play size={25} weight="fill" />}</button>
    </div>
  </section>;
}

function StatisticsScreen({ onBack }) {
  const [range, setRange] = useState("W");
  const [periodOffset, setPeriodOffset] = useState(0);
  const data = getStatistics(range, periodOffset);
  return <section className="statistics-screen">
    <header className="statistics-header">
      <button className="statistics-back" onClick={onBack} aria-label="返回计时器"><CaretLeft size={22} /></button>
      <div className="range-control" aria-label="统计范围">{["D", "W", "M", "Y"].map((item) => <button key={item} className={range === item ? "selected" : ""} aria-pressed={range === item} onClick={() => { setRange(item); setPeriodOffset(0); }}>{item}</button>)}</div>
    </header>
    <div className="period-switcher">
      <button onClick={() => setPeriodOffset((current) => current - 1)} aria-label="上一周期"><CaretLeft size={21} /></button>
      <strong>{data.period}</strong>
      <button onClick={() => setPeriodOffset((current) => Math.min(0, current + 1))} disabled={periodOffset === 0} aria-label="下一周期"><CaretRight size={21} /></button>
    </div>
    <div className={`compact-chart is-${range.toLowerCase()}`} style={{ "--bar-count": data.values.length }} role="img" aria-label={`${data.period}，${data.values.length}个刻度柱`}>
      {data.values.map((value, index) => <div className="chart-column" key={`${range}-${index}`}>
        <div className="chart-track"><span style={{ height: `${value}%` }} /></div>
        <small>{data.labels[index]}</small>
      </div>)}
    </div>
  </section>;
}

function MainMenu({ onNavigate, onClose, phase, onPhase, plan }) {
  const item = (icon, label, action, value) => <button role="menuitem" onClick={action}>{icon}<span>{label}</span>{value && <span className="menu-value">{value}</span>}</button>;
  return <div className="native-menu" role="menu">
    {item(<Timer size={17} />, "计时设置", () => onNavigate("plan"), `${plan.focus} / ${plan.shortBreak} · ${plan.cycles}轮`)}
    {item(<CaretRight size={17} />, phase === "focus" ? "开始休息" : "返回专注", () => onPhase(phase === "focus" ? "shortBreak" : "focus"))}
    {item(<ChartBar size={17} />, "统计", () => onNavigate("statistics"))}
    <div className="menu-separator" />
    {item(<Gear size={17} />, "设置…", () => onNavigate("settings"))}
    {item(<Info size={17} />, "关于 NanaFlow", () => onNavigate("about"))}
    {item(<X size={17} />, "关闭菜单", onClose)}
  </div>;
}

function StepperRow({ label, value, unit, onDecrease, onIncrease }) {
  return <div className="settings-row stepper-row"><span>{label}</span><div className="stepper"><button onClick={onDecrease} aria-label={`减少${label}`}><Minus size={14} /></button><strong>{value}<small>{unit}</small></strong><button onClick={onIncrease} aria-label={`增加${label}`}><Plus size={14} /></button></div></div>;
}

function PlanScreen({ plan, setPlan, onBack }) {
  const nudge = (key, delta, min, max) => setPlan((current) => ({ ...current, [key]: Math.min(max, Math.max(min, current[key] + delta)) }));
  return <section className="compact-panel"><BackHeader title="计时设置" onBack={onBack} action={<button className="text-action" onClick={onBack}>完成</button>} /><div className="panel-scroll plan-list">
    <p className="section-label">时长</p><div className="settings-group">
      <StepperRow label="专注" value={plan.focus} unit="分钟" onDecrease={() => nudge("focus", -5, 5, 90)} onIncrease={() => nudge("focus", 5, 5, 90)} />
      <StepperRow label="短休息" value={plan.shortBreak} unit="分钟" onDecrease={() => nudge("shortBreak", -1, 1, 30)} onIncrease={() => nudge("shortBreak", 1, 1, 30)} />
      <StepperRow label="长休息" value={plan.longBreak} unit="分钟" onDecrease={() => nudge("longBreak", -5, 5, 60)} onIncrease={() => nudge("longBreak", 5, 5, 60)} />
      <StepperRow label="循环" value={plan.cycles} unit="轮" onDecrease={() => nudge("cycles", -1, 1, 8)} onIncrease={() => nudge("cycles", 1, 1, 8)} />
    </div>
    <p className="section-label">自动开始</p><div className="settings-group">
      <div className="settings-row"><span>休息</span><Toggle checked={plan.autoBreak} onChange={(value) => setPlan({ ...plan, autoBreak: value })} label="自动开始休息" /></div>
      <div className="settings-row"><span>专注</span><Toggle checked={plan.autoFocus} onChange={(value) => setPlan({ ...plan, autoFocus: value })} label="自动开始专注" /></div>
    </div>
  </div></section>;
}

function SettingsScreen({ settings, setSettings, onBack }) {
  const set = (key, value) => setSettings((current) => ({ ...current, [key]: value }));
  const row = (key, label) => <div className="settings-row" key={key}><span>{label}</span><Toggle checked={settings[key]} onChange={(value) => set(key, value)} label={label} /></div>;
  return <section className="compact-panel"><BackHeader title="设置" onBack={onBack} /><div className="panel-scroll">
    <p className="section-label">启动</p><div className="settings-group">{row("login", "登录时启动")}{row("showWindow", "启动时显示窗口")}{row("hideOnStart", "计时开始后隐藏窗口")}</div>
    <p className="section-label">提醒</p><div className="settings-group">{row("notifications", "允许通知")}<div className="settings-row"><span>完成声音</span><span className="row-detail"><SpeakerHigh size={15} />铃声</span></div>{row("ticking", "专注时播放滴答声")}</div>
  </div></section>;
}

function AboutScreen({ onBack }) {
  return <section className="compact-panel"><BackHeader title="关于 NanaFlow" onBack={onBack} /><div className="about-content"><div className="app-mark"><Timer size={46} weight="light" /></div><h3>NanaFlow</h3><p>专注、休息、继续。</p><span>macOS 交互视觉稿</span><button onClick={onBack}>完成</button></div></section>;
}

function StatusMenu({ phase, running, time, windowVisible, onToggle, onShow, onStatistics, onSkip, onReset, onPlan, onSettings, onAbout, onQuit }) {
  const phaseTitle = phase === "focus" ? "专注" : phase === "shortBreak" ? "休息" : "长休息";
  const item = (icon, label, action) => <button role="menuitem" onClick={action}>{icon}<span>{label}</span></button>;
  return <div className="status-menu" role="menu">
    <div className="status-heading">{phaseTitle} · {time}</div>
    {item(running ? <Pause size={16} /> : <Play size={16} />, running ? "暂停" : "开始", onToggle)}
    {item(<Timer size={16} />, windowVisible ? "隐藏计时器" : "显示计时器", onShow)}
    {item(<ChartBar size={16} />, "显示统计", onStatistics)}
    <div className="menu-separator" />
    {item(<CaretRight size={16} />, phase === "focus" ? "跳到休息" : "跳到专注", onSkip)}
    {item(<ArrowCounterClockwise size={16} />, "重新开始", onReset)}
    <div className="menu-separator" />
    {item(<Timer size={16} />, "计时设置…", onPlan)}
    {item(<Gear size={16} />, "设置…", onSettings)}
    {item(<Info size={16} />, "关于 NanaFlow", onAbout)}
    <div className="menu-separator" />
    {item(<Power size={16} />, "退出 NanaFlow", onQuit)}
  </div>;
}

function formatTime(seconds) {
  return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

export function Prototype() {
  const [screen, setScreen] = useState("timer");
  const [menuOpen, setMenuOpen] = useState(false);
  const [statusOpen, setStatusOpen] = useState(false);
  const [windowVisible, setWindowVisible] = useState(true);
  const [running, setRunning] = useState(false);
  const [phase, setPhase] = useState("focus");
  const [cycle, setCycle] = useState(1);
  const [plan, setPlan] = useState({ focus: 25, shortBreak: 5, longBreak: 20, cycles: 4, autoBreak: false, autoFocus: false });
  const [seconds, setSeconds] = useState(plan.focus * 60);
  const [settings, setSettings] = useState({ login: true, showWindow: true, hideOnStart: false, notifications: true, ticking: false });

  useEffect(() => {
    if (!running) return undefined;
    const timer = window.setInterval(() => setSeconds((current) => {
      if (current > 1) return current - 1;
      const next = phase === "focus" ? (cycle === plan.cycles ? "longBreak" : "shortBreak") : "focus";
      setPhase(next);
      if (phase !== "focus") setCycle(cycle === plan.cycles ? 1 : cycle + 1);
      setRunning(next === "focus" ? plan.autoFocus : plan.autoBreak);
      return (next === "focus" ? plan.focus : next === "shortBreak" ? plan.shortBreak : plan.longBreak) * 60;
    }), 1000);
    return () => window.clearInterval(timer);
  }, [running, phase, cycle, plan]);

  const navigate = (next) => { setScreen(next); setWindowVisible(true); setMenuOpen(false); setStatusOpen(false); };
  const resetCycle = () => { setRunning(false); setCycle(1); setPhase("focus"); setSeconds(plan.focus * 60); };
  const switchPhase = (next) => { setRunning(false); setPhase(next); setSeconds((next === "focus" ? plan.focus : next === "shortBreak" ? plan.shortBreak : plan.longBreak) * 60); setMenuOpen(false); setStatusOpen(false); };
  const backFromPlan = () => { if (!running) setSeconds((phase === "focus" ? plan.focus : phase === "shortBreak" ? plan.shortBreak : plan.longBreak) * 60); setScreen("timer"); };
  const time = formatTime(seconds);

  return <main className="prototype-stage" onClick={() => statusOpen && setStatusOpen(false)}>
    <div className="mac-menu-strip">
      <span className="menu-strip-context">macOS 菜单栏预览</span>
      <div className="status-area">
        <button className={`status-item ${running ? "is-running" : ""}`} aria-label={`NanaFlow，${time}`} onClick={(event) => { event.stopPropagation(); setStatusOpen(!statusOpen); }}>
          <span>{time}</span>
        </button>
        {statusOpen && <StatusMenu phase={phase} running={running} time={time} windowVisible={windowVisible} onToggle={() => setRunning(!running)} onShow={() => { setWindowVisible(!windowVisible); setStatusOpen(false); }} onStatistics={() => navigate("statistics")} onSkip={() => switchPhase(phase === "focus" ? "shortBreak" : "focus")} onReset={resetCycle} onPlan={() => navigate("plan")} onSettings={() => navigate("settings")} onAbout={() => navigate("about")} onQuit={() => { setWindowVisible(false); setStatusOpen(false); }} />}
      </div>
    </div>

    {!windowVisible ? <button className="restore-window" onClick={() => setWindowVisible(true)}><Timer size={20} />显示 NanaFlow</button> : <div className="window-wrap">
      {screen === "timer" && <TimerScreen phase={phase} seconds={seconds} running={running} cycle={cycle} totalCycles={plan.cycles} onToggle={() => { setRunning(!running); if (!running && settings.hideOnStart) setWindowVisible(false); }} onReset={resetCycle} onMenu={() => setMenuOpen(!menuOpen)} onStatistics={() => navigate("statistics")} onClose={() => setWindowVisible(false)} />}
      {screen === "statistics" && <StatisticsScreen onBack={() => setScreen("timer")} />}
      {screen === "plan" && <PlanScreen plan={plan} setPlan={setPlan} onBack={backFromPlan} />}
      {screen === "settings" && <SettingsScreen settings={settings} setSettings={setSettings} onBack={() => setScreen("timer")} />}
      {screen === "about" && <AboutScreen onBack={() => setScreen("timer")} />}
      {menuOpen && <MainMenu phase={phase} plan={plan} onNavigate={navigate} onClose={() => setMenuOpen(false)} onPhase={switchPhase} />}
    </div>}

    <div className="prototype-note"><span>顶部菜单栏可点击</span><span>统计在主窗口内切换</span></div>
  </main>;
}
