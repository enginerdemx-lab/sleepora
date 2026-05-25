/* global React, ReactDOM */
const { useState, useEffect, useMemo, useCallback } = React;

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accentHue": 268,
  "density": "default",
  "sidebar": "expanded",
  "radius": 14
}/*EDITMODE-END*/;

// ───── Icons ─────
const Icon = ({ name, size = 16 }) => {
  const s = size;
  const common = { width: s, height: s, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", strokeWidth: 1.6, strokeLinecap: "round", strokeLinejoin: "round" };
  const paths = {
    home: <><path d="M3 11l9-8 9 8" /><path d="M5 10v10h14V10" /></>,
    users: <><circle cx="9" cy="8" r="3.5" /><path d="M2.5 20c0-3.5 3-6 6.5-6s6.5 2.5 6.5 6" /><circle cx="17" cy="9" r="2.5" /><path d="M15 14.5c2.5 0 6 1.5 6 5.5" /></>,
    star: <path d="M12 3l2.6 5.6 6 .9-4.4 4.2 1.1 6L12 16.9 6.7 19.7l1.1-6L3.4 9.5l6-.9z" />,
    chat: <path d="M21 12a8 8 0 0 1-11.5 7.2L4 21l1.8-5.5A8 8 0 1 1 21 12z" />,
    bar: <><path d="M4 20V10" /><path d="M10 20V4" /><path d="M16 20v-7" /><path d="M22 20H2" /></>,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></>,
    moon: <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" />,
    bell: <><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" /><path d="M10 21a2 2 0 0 0 4 0" /></>,
    search: <><circle cx="11" cy="11" r="7" /><path d="M21 21l-4.3-4.3" /></>,
    arrow: <><path d="M5 12h14" /><path d="M13 6l6 6-6 6" /></>,
    plus: <><path d="M12 5v14" /><path d="M5 12h14" /></>,
    download: <><path d="M12 3v12" /><path d="M7 11l5 5 5-5" /><path d="M5 21h14" /></>,
    logout: <><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><path d="M16 17l5-5-5-5" /><path d="M21 12H9" /></>,
    sparkle: <><path d="M12 3l1.8 4.5L18 9.5l-4.2 2L12 16l-1.8-4.5L6 9.5l4.2-2z" /><path d="M19 15l.7 1.7L21 17l-1.3.4L19 19l-.7-1.6L17 17l1.3-.3z" /></>,
    trend: <><path d="M3 17l6-6 4 4 7-9" /><path d="M14 6h6v6" /></>,
    leaf: <><path d="M21 3s-9 1-13 5S3 17 3 21c4 0 9-1 13-5s5-9 5-13z" /><path d="M3 21l9-9" /></>,
    refresh: <><path d="M3 12a9 9 0 0 1 15.5-6.3L21 8" /><path d="M21 3v5h-5" /><path d="M21 12a9 9 0 0 1-15.5 6.3L3 16" /><path d="M3 21v-5h5" /></>,
    check: <path d="M20 6L9 17l-5-5" />,
    trash: <><path d="M3 6h18" /><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" /><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" /></>,
    menu: <><path d="M4 6h16" /><path d="M4 12h16" /><path d="M4 18h16" /></>,
    close: <><path d="M18 6L6 18" /><path d="M6 6l12 12" /></>,
  };
  return <svg {...common}>{paths[name]}</svg>;
};

// ───── Helpers ─────
const tsToDate = (ts) => {
  if (!ts) return null;
  if (ts.toDate) return ts.toDate();
  if (ts.seconds) return new Date(ts.seconds * 1000);
  if (ts instanceof Date) return ts;
  try { return new Date(ts); } catch { return null; }
};

const fmtDate = (ts) => {
  const d = tsToDate(ts);
  if (!d || isNaN(d.getTime())) return "–";
  return d.toLocaleDateString("tr-TR", { day: "2-digit", month: "short", year: "numeric" });
};

const fmtRelative = (ts) => {
  const d = tsToDate(ts);
  if (!d || isNaN(d.getTime())) return "–";
  const diff = (Date.now() - d.getTime()) / 1000;
  if (diff < 60) return "şimdi";
  if (diff < 3600) return `${Math.floor(diff / 60)}d önce`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}s önce`;
  if (diff < 86400 * 7) return `${Math.floor(diff / 86400)}g önce`;
  return d.toLocaleDateString("tr-TR", { day: "2-digit", month: "short" });
};

const initials = (name, email) => {
  const src = (name || email || "?").trim();
  const parts = src.split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return src.slice(0, 2).toUpperCase();
};

const hueFromString = (str) => {
  let h = 0;
  for (const c of (str || "?")) h = (h * 31 + c.charCodeAt(0)) & 0xffff;
  return h % 360;
};

// ───── Toast ─────
let _toastId = 0;
const ToastContext = React.createContext({ push: () => {} });

const ToastProvider = ({ children }) => {
  const [toasts, setToasts] = useState([]);
  const push = useCallback((msg, kind = "info") => {
    const id = ++_toastId;
    setToasts(t => [...t, { id, msg, kind }]);
    setTimeout(() => setToasts(t => t.filter(x => x.id !== id)), 3500);
  }, []);
  return (
    <ToastContext.Provider value={{ push }}>
      {children}
      <div style={{ position: "fixed", bottom: 24, right: 24, display: "flex", flexDirection: "column", gap: 8, zIndex: 9999 }}>
        {toasts.map(t => (
          <div key={t.id} style={{
            background: "var(--bg-2)", border: "1px solid var(--line-2)",
            color: "var(--fg-0)", padding: "10px 14px", borderRadius: 10,
            fontSize: 13, boxShadow: "0 8px 24px rgba(0,0,0,0.35)",
            borderLeft: `3px solid ${t.kind === "error" ? "var(--bad)" : t.kind === "success" ? "var(--good)" : "var(--accent)"}`,
            minWidth: 240, maxWidth: 360
          }}>{t.msg}</div>
        ))}
      </div>
    </ToastContext.Provider>
  );
};
const useToast = () => React.useContext(ToastContext);

// ───── Data Provider ─────
const DataContext = React.createContext({});

const DataProvider = ({ children }) => {
  const [users, setUsers] = useState([]);
  const [feedbacks, setFeedbacks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [authReady, setAuthReady] = useState(!!window._fbUser);

  const fetchAll = useCallback(async () => {
    if (!window._fbDb || !window._fb) return;
    setLoading(true);
    setError(null);
    try {
      const { collection, getDocs, query, orderBy } = window._fb;
      const db = window._fbDb;
      let uDocs = [];
      try {
        const uSnap = await getDocs(collection(db, "users"));
        uDocs = uSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      } catch (e) { console.error("Kullanıcılar çekilemedi:", e); }
      
      let fDocs = [];
      try {
        const fSnap = await getDocs(query(collection(db, "feedbacks"), orderBy("created_at", "desc")));
        fDocs = fSnap.docs.map(d => ({ id: d.id, ...d.data() }));
      } catch (e) { console.error("Geri bildirimler çekilemedi:", e); }

      setUsers(uDocs);
      setFeedbacks(fDocs);
      
      if (uDocs.length === 0 && fDocs.length === 0) {
        // Eğer her ikisi de çekilemediyse veya boşsa, hata var mı kontrol edebiliriz
        // Ancak güvenlik kuralları vs. engellediyse konsolda hata görünür
      }
    } catch (e) {
      console.error("Veri yükleme hatası:", e);
      setError(e.message || "Veri yüklenemedi");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const onAuth = () => { setAuthReady(true); fetchAll(); };
    if (window._fbUser) { setAuthReady(true); fetchAll(); }
    else window.addEventListener("admin-auth-ready", onAuth);
    return () => window.removeEventListener("admin-auth-ready", onAuth);
  }, [fetchAll]);

  // Derived metrics
  const metrics = useMemo(() => {
    const total = users.length;
    const premium = users.filter(u => u.is_premium).length;
    const conv = total > 0 ? (premium / total) * 100 : 0;
    const unread = feedbacks.filter(f => !f.is_read).length;
    const now = new Date();
    const sevenDayMs = 7 * 86400 * 1000;
    const last7 = new Date(now.getTime() - sevenDayMs);
    const newThisWeek = users.filter(u => {
      const d = tsToDate(u.created_at);
      return d && d >= last7;
    }).length;
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const newToday = users.filter(u => {
      const d = tsToDate(u.created_at);
      return d && d >= today;
    }).length;
    const activeWeek = users.filter(u => {
      const d = tsToDate(u.last_login);
      return d && d >= last7;
    }).length;
    const onboarded = users.filter(u => (u.baby_name && u.baby_name.length > 0)).length;
    const weeklyGrowthPct = total > 0 ? (newThisWeek / total) * 100 : 0;
    return { total, premium, conv, unread, newThisWeek, newToday, activeWeek, onboarded, weeklyGrowthPct, feedbackTotal: feedbacks.length };
  }, [users, feedbacks]);

  return (
    <DataContext.Provider value={{ users, feedbacks, setUsers, setFeedbacks, loading, error, metrics, refresh: fetchAll, authReady }}>
      {children}
    </DataContext.Provider>
  );
};
const useData = () => React.useContext(DataContext);

// ───── Sidebar ─────
const PAGES = [
  { id: "dash",        label: "Dashboard",         icon: "home" },
  { id: "users",       label: "Kullanıcılar",      icon: "users" },
  { id: "premium",     label: "Premium",           icon: "star" },
  { id: "feedback",    label: "Geri Bildirimler",  icon: "chat" },
  { id: "leaderboard", label: "Leaderboard",       icon: "bar" },
  { id: "sleep",       label: "Uyku Verileri",     icon: "moon" },
];
const TOOLS = [
  { id: "settings", label: "Ayarlar", icon: "settings" },
];

const Sidebar = ({ page, onNavigate, mobileOpen }) => {
  const { metrics } = useData();
  const badges = {
    users: metrics.total > 0 ? metrics.total.toLocaleString("tr-TR") : null,
    premium: metrics.premium > 0 ? String(metrics.premium) : null,
    feedback: metrics.unread > 0 ? String(metrics.unread) : null,
  };
  const adminEmail = window._fbUser?.email || "destek@sleepora.app";
  const adminInit = adminEmail.slice(0, 2).toUpperCase();

  return (
    <aside className={`sidebar ${mobileOpen ? "mobile-open" : ""}`}>
      <div className="brand">
        <img src="logo.jpg" alt="Sleepora" className="brand-logo" />
        <div className="brand-text">
          <span className="brand-name">Sleepora</span>
          <span className="brand-sub">Admin · v3.4</span>
        </div>
      </div>

      <div>
        <div className="nav-section-label">Genel</div>
        <nav className="nav">
          {PAGES.map(it => (
            <div key={it.id} role="button" tabIndex={0}
              className={`nav-item ${page === it.id ? "active" : ""}`}
              onClick={() => onNavigate(it.id)}
              onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") onNavigate(it.id); }}>
              <Icon name={it.icon} size={17} />
              <span className="nav-label">{it.label}</span>
              {badges[it.id] && <span className={`nav-badge ${it.id === "feedback" && metrics.unread > 0 ? "hot" : ""}`}>{badges[it.id]}</span>}
            </div>
          ))}
        </nav>
      </div>

      <div>
        <div className="nav-section-label">Araçlar</div>
        <nav className="nav">
          {TOOLS.map(it => (
            <div key={it.id} role="button" tabIndex={0}
              className={`nav-item ${page === it.id ? "active" : ""}`}
              onClick={() => onNavigate(it.id)}
              onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") onNavigate(it.id); }}>
              <Icon name={it.icon} size={17} />
              <span className="nav-label">{it.label}</span>
            </div>
          ))}
        </nav>
      </div>

      <div className="sidebar-footer">
        <div className="footer-card">
          <div className="avatar">{adminInit}</div>
          <div className="footer-meta">
            <div className="footer-name">Admin</div>
            <div className="footer-email">{adminEmail}</div>
          </div>
        </div>
        <div className="signout" role="button" tabIndex={0}
          onClick={() => window._signOut?.()}
          onKeyDown={(e) => { if (e.key === "Enter") window._signOut?.(); }}>
          <Icon name="logout" size={15} />
          <span>Çıkış</span>
        </div>
      </div>
    </aside>
  );
};

// ───── Topbar ─────
const Topbar = ({ page, onRefresh, onMenuToggle }) => {
  const [time, setTime] = useState(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 30_000);
    return () => clearInterval(id);
  }, []);
  const fmt = time.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  const dateFmt = time.toLocaleDateString("tr-TR", { day: "2-digit", month: "long", year: "numeric" });

  const titles = {
    dash:        ["Genel", "bakış",        "Anasayfa · Dashboard"],
    users:       ["Tüm",  "kullanıcılar", "Anasayfa · Kullanıcılar"],
    premium:     ["Premium", "üyeler",    "Anasayfa · Premium"],
    feedback:    ["Geri",  "bildirimler", "Anasayfa · Geri Bildirimler"],
    leaderboard: ["Lider", "tablosu",     "Anasayfa · Leaderboard"],
    sleep:       ["Uyku",  "verileri",    "Anasayfa · Uyku Verileri"],
    settings:    ["Sistem", "ayarları",   "Anasayfa · Ayarlar"],
  };
  const [t1, t2, crumb] = titles[page] || titles.dash;

  return (
    <header className="topbar">
      <div className="topbar-left">
        <div className="hamburger" role="button" tabIndex={0} onClick={onMenuToggle}
          onKeyDown={e => { if (e.key === "Enter") onMenuToggle(); }}>
          <Icon name="menu" size={18} />
        </div>
        <h1 className="page-title">{t1} <em>{t2}</em></h1>
        <span className="crumb">{crumb.split(" · ").map((p, i, arr) => i === arr.length - 1 ? <b key={i}>{p}</b> : <React.Fragment key={i}>{p} · </React.Fragment>)}</span>
      </div>
      <div className="topbar-right">
        <div className="search">
          <Icon name="search" size={14} />
          <input placeholder="Kullanıcı, geri bildirim ara…" />
          <span className="kbd">⌘K</span>
        </div>
        <div className="icon-btn" role="button" tabIndex={0} title="Yenile" onClick={onRefresh}>
          <Icon name="refresh" size={16} />
        </div>
        <div className="clock">
          <span className="pulse-dot" />
          <span>{dateFmt}</span>
          <span style={{ color: "var(--fg-2)" }}>·</span>
          <span style={{ fontVariantNumeric: "tabular-nums" }}>{fmt}</span>
        </div>
      </div>
    </header>
  );
};

// ───── Hero ─────
const Hero = () => {
  const { metrics, users } = useData();
  const userName = (window._fbUser?.email || "").split("@")[0] || "yönetici";
  const cap = userName.charAt(0).toUpperCase() + userName.slice(1);

  // Cumulative signup curve over last 14 days for the "tonight" card
  const last14 = useMemo(() => {
    const days = [];
    const now = new Date();
    for (let i = 13; i >= 0; i--) {
      const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const next = new Date(day.getTime() + 86400000);
      const c = users.filter(u => {
        const d = tsToDate(u.created_at);
        return d && d >= day && d < next;
      }).length;
      days.push({ day, c });
    }
    return days;
  }, [users]);
  const max14 = Math.max(1, ...last14.map(d => d.c));

  return (
    <section className="hero">
      <div className="hero-greeting">
        <div className="greeting-eyebrow">
          <span className="dot" />
          {new Date().toLocaleDateString("tr-TR", { weekday: "long", day: "numeric", month: "long" })}
        </div>
        <h2 className="greeting-h">
          Merhaba, {cap}.{" "}
          <em>
            {metrics.total > 0
              ? `Sleepora bu gece ${metrics.total.toLocaleString("tr-TR")} kayıtlı kullanıcıya hizmet veriyor.`
              : "Henüz kayıtlı kullanıcı yok — uygulamayı yayına aldığında veriler burada görünecek."}
          </em>
        </h2>
        <div className="greeting-meta">
          <span><b>+{metrics.newToday}</b> bugün kayıt</span>
          <span><b>%{metrics.weeklyGrowthPct.toFixed(1)}</b> haftalık büyüme</span>
          <span><b>{metrics.activeWeek}</b> haftalık aktif</span>
        </div>
      </div>
      <div className="moon-card">
        <div className="moon-card-h">
          <span>Son 14 gün · kayıt akışı</span>
          <span style={{ fontFamily: "Geist Mono, monospace", color: "var(--fg-1)" }}>+{metrics.newThisWeek} / 7g</span>
        </div>
        <div className="phase-vis" style={{ alignItems: "flex-end", height: 90 }}>
          {last14.map((d, i) => {
            const peak = d.c === max14 && d.c > 0;
            return (
              <div key={i} className={`phase ${peak ? "peak" : ""}`}>
                <div className="phase-bar" style={{ height: `${Math.max(2, (d.c / max14) * 80)}px` }} />
                <span className="phase-time">{d.day.getDate()}</span>
              </div>
            );
          })}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 11.5, color: "var(--fg-2)" }}>
          <span>14 gün önce</span>
          <span>{max14 > 0 ? `Pik · ${max14} kayıt` : "Veri yok"}</span>
          <span>Bugün</span>
        </div>
      </div>
    </section>
  );
};

// ───── Sparkline (real data from buckets) ─────
const Spark = ({ data, color, fillId }) => {
  const w = 120, h = 28;
  if (!data || data.length === 0) {
    return <svg className="spark" viewBox={`0 0 ${w} ${h}`}></svg>;
  }
  const max = Math.max(...data), min = Math.min(...data);
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1 || 1)) * w;
    const y = h - ((v - min) / range) * h;
    return [x, y];
  });
  const d = pts.map((p, i) => `${i === 0 ? "M" : "L"} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(" ");
  const dArea = `${d} L ${w} ${h} L 0 ${h} Z`;
  return (
    <svg className="spark" viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
      <defs>
        <linearGradient id={fillId} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.35" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={dArea} fill={`url(#${fillId})`} />
      <path d={d} fill="none" stroke={color} strokeWidth="1.4" />
    </svg>
  );
};

// ───── Stats ─────
const Stats = ({ onNav }) => {
  const { metrics, users, feedbacks, loading } = useData();

  // Build sparklines from real data — last 14 days
  const sparks = useMemo(() => {
    const N = 14;
    const buckets = (items, dateField) => {
      const arr = new Array(N).fill(0);
      const now = new Date();
      const base = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (N - 1));
      items.forEach(it => {
        const d = tsToDate(it[dateField]);
        if (!d) return;
        const idx = Math.floor((d - base) / 86400000);
        if (idx >= 0 && idx < N) arr[idx]++;
      });
      // cumulative for users/premium so the line goes up
      return arr;
    };
    const cumulate = (arr) => {
      const out = []; let s = 0;
      for (const v of arr) { s += v; out.push(s); }
      return out;
    };
    const userBuckets = buckets(users, "created_at");
    const premiumUsers = users.filter(u => u.is_premium);
    const premiumBuckets = buckets(premiumUsers, "subscription_start");
    const fbBuckets = buckets(feedbacks, "created_at");
    return {
      users: cumulate(userBuckets),
      premium: cumulate(premiumBuckets),
      feedback: fbBuckets,
    };
  }, [users, feedbacks]);

  const empty = !loading && metrics.total === 0;

  const stats = [
    {
      k: "Toplam Kullanıcı", v: metrics.total.toLocaleString("tr-TR"),
      icon: "users", iclass: "users",
      delta: metrics.weeklyGrowthPct > 0 ? `+${metrics.weeklyGrowthPct.toFixed(1)}%` : "0%",
      up: metrics.weeklyGrowthPct >= 0,
      spark: sparks.users, color: "oklch(0.78 0.10 230)",
      action: "users"
    },
    {
      k: "Premium Üye", v: metrics.premium.toLocaleString("tr-TR"),
      icon: "star", iclass: "premium",
      delta: metrics.premium > 0 ? `${metrics.premium} aktif` : "0 aktif",
      up: true,
      spark: sparks.premium, color: "oklch(0.80 0.13 75)",
    },
    {
      k: "Geri Bildirim", v: metrics.feedbackTotal.toLocaleString("tr-TR"),
      icon: "chat", iclass: "feedback",
      delta: metrics.unread > 0 ? `+${metrics.unread} okunmamış` : "tümü okundu",
      up: metrics.unread === 0,
      spark: sparks.feedback, color: "var(--accent)",
    },
    {
      k: "Dönüşüm Oranı",
      v: metrics.total > 0 ? `${metrics.conv.toFixed(2)}%` : "—",
      icon: "trend", iclass: "conversion",
      delta: metrics.total > 0 ? `${metrics.premium}/${metrics.total}` : "—",
      up: metrics.conv >= 1,
      spark: sparks.users, color: "oklch(0.78 0.12 155)",
    },
  ];

  return (
    <section className="stat-grid">
      {stats.map((s, i) => (
        <div key={i} className="stat" onClick={() => s.action && onNav && onNav(s.action)} style={s.action ? {cursor: "pointer"} : {}}>
          <div className="stat-h">
            <span>{s.k}</span>
            <div className={`stat-icon ${s.iclass}`}><Icon name={s.icon} size={15} /></div>
          </div>
          <div className={`stat-value ${empty ? "empty" : ""}`}>{loading ? "…" : s.v}</div>
          <div className="stat-foot">
            {empty ? (
              <span style={{ color: "var(--fg-3)", fontSize: 12 }}>veri henüz yok</span>
            ) : (
              <>
                <span className={`delta ${s.up ? "up" : "down"}`}>
                  {s.up ? "↑" : "↓"} {s.delta}
                </span>
                <Spark data={s.spark} color={s.color} fillId={`spk${i}`} />
              </>
            )}
          </div>
        </div>
      ))}
    </section>
  );
};

// ───── Growth chart (real signups) ─────
const GrowthChart = () => {
  const { users } = useData();
  const [range, setRange] = useState("30g");
  const days = range === "7g" ? 7 : range === "30g" ? 30 : 90;

  const data = useMemo(() => {
    const arr = new Array(days).fill(0);
    const now = new Date();
    const base = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (days - 1));
    users.forEach(u => {
      const d = tsToDate(u.created_at);
      if (!d) return;
      const idx = Math.floor((d - base) / 86400000);
      if (idx >= 0 && idx < days) arr[idx]++;
    });
    return arr;
  }, [users, days]);

  const dataP = useMemo(() => {
    const arr = new Array(days).fill(0);
    const now = new Date();
    const base = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (days - 1));
    users.filter(u => u.is_premium).forEach(u => {
      const d = tsToDate(u.subscription_start) || tsToDate(u.created_at);
      if (!d) return;
      const idx = Math.floor((d - base) / 86400000);
      if (idx >= 0 && idx < days) arr[idx]++;
    });
    return arr;
  }, [users, days]);

  const w = 720, h = 220, pad = 28;
  const max = Math.max(1, ...data) * 1.1;
  const xStep = (w - pad * 2) / Math.max(1, data.length - 1);
  const toPath = (arr) => arr.map((v, i) => {
    const x = pad + i * xStep;
    const y = h - pad - (v / max) * (h - pad * 2);
    return `${i === 0 ? "M" : "L"} ${x.toFixed(1)} ${y.toFixed(1)}`;
  }).join(" ");
  const areaPath = (arr) => `${toPath(arr)} L ${pad + (arr.length - 1) * xStep} ${h - pad} L ${pad} ${h - pad} Z`;

  const total = data.reduce((a, b) => a + b, 0);
  const totalP = dataP.reduce((a, b) => a + b, 0);
  const yTicks = [0, 0.5, 1].map(t => Math.round(max * t));
  const isEmpty = total === 0;

  const handleExport = () => {
    const rows = [["gün", "yeni_kullanıcı", "yeni_premium"]];
    const now = new Date();
    const base = new Date(now.getFullYear(), now.getMonth(), now.getDate() - (days - 1));
    for (let i = 0; i < days; i++) {
      const d = new Date(base.getTime() + i * 86400000);
      rows.push([d.toISOString().slice(0, 10), data[i], dataP[i]]);
    }
    const csv = rows.map(r => r.join(",")).join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a"); a.href = url;
    a.download = `sleepora-growth-${range}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Kullanıcı Büyümesi</h3>
          <span className="panel-sub">Son {range === "7g" ? "7 gün" : range === "30g" ? "30 gün" : "90 gün"} — yeni kayıtlar</span>
        </div>
        <div className="panel-h-right">
          <div className="seg">
            {["7g", "30g", "90g"].map(r => (
              <button key={r} className={range === r ? "on" : ""} onClick={() => setRange(r)}>{r}</button>
            ))}
          </div>
          <div className="panel-action" onClick={handleExport} role="button" tabIndex={0}>
            <Icon name="download" size={13} /> Dışa aktar
          </div>
        </div>
      </div>
      <div className="panel-body">
        <div className="chart-summary">
          <div>
            <div className="chart-stat-l">Toplam yeni kayıt</div>
            <div className="chart-stat-v">{total.toLocaleString("tr-TR")}</div>
          </div>
          <div>
            <div className="chart-stat-l">Yeni premium</div>
            <div className="chart-stat-v">{totalP.toLocaleString("tr-TR")} <small>{total > 0 ? `%${((totalP / total) * 100).toFixed(1)}` : "—"}</small></div>
          </div>
          <div>
            <div className="chart-stat-l">Günlük ortalama</div>
            <div className="chart-stat-v">{(total / days).toFixed(1)}<small>/gün</small></div>
          </div>
        </div>

        <div className="chart-legend">
          <div className="legend-item"><span className="legend-sw" style={{ background: "var(--accent)" }}></span> Yeni kullanıcı</div>
          <div className="legend-item"><span className="legend-sw" style={{ background: "oklch(0.80 0.13 75)" }}></span> Yeni premium</div>
        </div>

        <div className="chart-wrap">
          {isEmpty ? (
            <div className="empty" style={{ padding: 60 }}>
              <div className="empty-glyph"><Icon name="trend" size={20} /></div>
              <div className="empty-title">Bu dönemde kayıt verisi yok</div>
              <div className="empty-sub">Yeni kullanıcı kayıtları burada görünecek.</div>
            </div>
          ) : (
            <svg viewBox={`0 0 ${w} ${h}`} width="100%" height="100%" preserveAspectRatio="none">
              <defs>
                <linearGradient id="fillA" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0%" stopColor="var(--accent)" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="var(--accent)" stopOpacity="0" />
                </linearGradient>
              </defs>
              {yTicks.map((t, i) => {
                const y = h - pad - (t / max) * (h - pad * 2);
                return (
                  <g key={i}>
                    <line x1={pad} x2={w - pad} y1={y} y2={y} stroke="var(--line)" strokeDasharray="3 4" />
                    <text x={4} y={y + 3} fill="var(--fg-3)" fontSize="9" fontFamily="Geist Mono, monospace">{t}</text>
                  </g>
                );
              })}
              <path d={areaPath(data)} fill="url(#fillA)" />
              <path d={toPath(data)} fill="none" stroke="var(--accent)" strokeWidth="1.8" />
              <path d={toPath(dataP)} fill="none" stroke="oklch(0.80 0.13 75)" strokeWidth="1.4" strokeDasharray="3 3" />
              {data.map((v, i) => {
                if (i % Math.ceil(data.length / 8) !== 0) return null;
                const x = pad + i * xStep;
                return <text key={i} x={x} y={h - 8} fill="var(--fg-3)" fontSize="9" textAnchor="middle" fontFamily="Geist Mono, monospace">{i + 1}</text>;
              })}
            </svg>
          )}
        </div>
      </div>
    </div>
  );
};

// ───── Funnel (real) ─────
const Funnel = () => {
  const { users } = useData();
  const total = users.length;
  const onboarded = users.filter(u => u.baby_name && u.baby_name.length > 0).length;
  const now = Date.now();
  const active7 = users.filter(u => {
    const d = tsToDate(u.last_login); return d && (now - d.getTime() < 7 * 86400000);
  }).length;
  const premium = users.filter(u => u.is_premium).length;

  const steps = [
    { l: "Hesap oluşturma", v: total },
    { l: "Onboarding tamam", v: onboarded },
    { l: "Son 7 gün aktif", v: active7 },
    { l: "Premium üyelik", v: premium },
  ].map(s => ({ ...s, p: total > 0 ? (s.v / total) * 100 : 0 }));

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Premium hunisi</h3>
          <span className="panel-sub">Kayıttan ödemeye yolculuk</span>
        </div>
      </div>
      <div className="panel-body">
        {total === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="bar" size={20} /></div>
            <div className="empty-title">Henüz veri yok</div>
            <div className="empty-sub">Kullanıcı kayıtları başladıktan sonra huni doldurulacak.</div>
          </div>
        ) : (
          <div className="funnel">
            {steps.map((s, i) => (
              <div key={i} className="funnel-step">
                <div className="funnel-step-h">
                  <span className="funnel-step-l">{s.l}</span>
                  <span className="funnel-step-v">{s.v.toLocaleString("tr-TR")} <small>%{s.p.toFixed(1)}</small></span>
                </div>
                <div className="funnel-track">
                  <div className="funnel-fill" style={{ width: `${Math.max(2, s.p)}%`, opacity: 0.4 + (i * 0.15) }} />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Recent users ─────
const RecentUsers = ({ onViewAll }) => {
  const { users, loading } = useData();
  const recent = useMemo(() =>
    [...users].sort((a, b) => {
      const ta = tsToDate(a.created_at)?.getTime() || 0;
      const tb = tsToDate(b.created_at)?.getTime() || 0;
      return tb - ta;
    }).slice(0, 6)
  , [users]);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Son katılan kullanıcılar</h3>
          <span className="panel-sub">{users.length > 0 ? `${users.length} toplam kayıt` : "Bugün kayıt yok"}</span>
        </div>
        <div className="panel-action" onClick={onViewAll} role="button" tabIndex={0}>Tümü <Icon name="arrow" size={13} /></div>
      </div>
      <div className="panel-body">
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : recent.length > 0 ? (
          <div className="ulist">
            {recent.map((u) => {
              const hue = hueFromString(u.email || u.id);
              return (
                <div key={u.id} className="ulist-row">
                  <div className="uavatar" style={{ background: `linear-gradient(135deg, oklch(0.65 0.14 ${hue}), oklch(0.45 0.14 var(--accent-h)))` }}>
                    {initials(u.display_name, u.email)}
                  </div>
                  <div>
                    <div className="uname">{u.display_name || "Anonim"}</div>
                    <div className="uemail">{u.email || u.id}</div>
                  </div>
                  {u.is_premium && <span className="ubadge premium">Premium</span>}
                  <span className="utime">{fmtRelative(u.created_at)}</span>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="empty">
            <div className="empty-glyph"><Icon name="users" size={20} /></div>
            <div className="empty-title">Kullanıcı bulunamadı</div>
            <div className="empty-sub">Yeni kayıtlar burada gerçek zamanlı olarak görünecek.</div>
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Recent feedback ─────
const RecentFeedback = ({ onViewAll }) => {
  const { feedbacks, loading } = useData();
  const recent = feedbacks.slice(0, 4);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Son geri bildirimler</h3>
          <span className="panel-sub">{feedbacks.length > 0 ? `${feedbacks.length} toplam` : "Henüz geri bildirim yok"}</span>
        </div>
        <div className="panel-action" onClick={onViewAll} role="button" tabIndex={0}>Tümü <Icon name="arrow" size={13} /></div>
      </div>
      <div className="panel-body">
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : recent.length > 0 ? (
          <div>
            {recent.map((f) => {
              const hue = hueFromString(f.email || f.id);
              const name = f.display_name || f.email || "Anonim";
              return (
                <div key={f.id} className="fb-row">
                  <div className="uavatar" style={{ width: 28, height: 28, fontSize: 11, background: `linear-gradient(135deg, oklch(0.65 0.14 ${hue}), oklch(0.45 0.14 var(--accent-h)))` }}>
                    {initials(name)}
                  </div>
                  <div className="fb-content">
                    <div className="fb-h">
                      <span className="fb-author">{name}</span>
                      {!f.is_read && <span className="ubadge new" style={{ fontSize: 9.5 }}>Yeni</span>}
                      <span className="fb-tag">· {f.platform || "ios"}{f.app_version ? ` · v${f.app_version}` : ""}</span>
                      <span className="fb-tag" style={{ marginLeft: "auto" }}>{fmtRelative(f.created_at)}</span>
                    </div>
                    <div className="fb-text">{f.message || "—"}</div>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <div className="empty">
            <div className="empty-glyph"><Icon name="chat" size={20} /></div>
            <div className="empty-title">Geri bildirim bulunamadı</div>
            <div className="empty-sub">Kullanıcı yorumları burada toplanacak.</div>
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Heatmap (real signups by hour × day-of-week) ─────
const Heatmap = () => {
  const { users } = useData();
  const dayLabels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
  const grid = useMemo(() => {
    // Mon=0 ... Sun=6
    const g = Array.from({ length: 7 }, () => new Array(24).fill(0));
    users.forEach(u => {
      const d = tsToDate(u.created_at);
      if (!d) return;
      const dow = (d.getDay() + 6) % 7; // make Mon=0
      g[dow][d.getHours()]++;
    });
    return g;
  }, [users]);

  const max = Math.max(1, ...grid.flat());
  const hasData = grid.flat().some(v => v > 0);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Kayıt ısı haritası</h3>
          <span className="panel-sub">Gün × saat — kullanıcı kayıt zamanları</span>
        </div>
      </div>
      <div className="panel-body">
        {!hasData ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="sparkle" size={20} /></div>
            <div className="empty-title">Henüz veri yok</div>
            <div className="empty-sub">Kullanıcılar kaydoldukça ısı haritası dolacak.</div>
          </div>
        ) : (
          <>
            <div className="heatmap">
              <div></div>
              {Array.from({ length: 24 }).map((_, h) => (
                <div key={h} className="heat-x">{h % 6 === 0 ? h : ""}</div>
              ))}
              {dayLabels.map((d, di) => (
                <React.Fragment key={d}>
                  <div className="heat-y">{d}</div>
                  {Array.from({ length: 24 }).map((_, h) => {
                    const v = grid[di][h];
                    const intensity = v / max;
                    const bg = v === 0 ? "var(--bg-3)" : `oklch(${0.32 + intensity * 0.4} ${0.05 + intensity * 0.10} var(--accent-h))`;
                    return <div key={h} className="heat-cell" style={{ background: bg }} title={`${d} ${h}:00 — ${v} kayıt`} />;
                  })}
                </React.Fragment>
              ))}
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", marginTop: 14, fontSize: 11, color: "var(--fg-2)", fontFamily: "Geist Mono, monospace" }}>
              <span>0 kayıt</span>
              <div style={{ display: "flex", gap: 3, alignItems: "center" }}>
                {[0.1, 0.3, 0.5, 0.7, 0.9].map((v, i) => (
                  <div key={i} style={{ width: 18, height: 8, borderRadius: 2, background: `oklch(${0.32 + v * 0.4} ${0.05 + v * 0.10} var(--accent-h))` }} />
                ))}
              </div>
              <span>{max}+ kayıt</span>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

// ───── Live activity (real events from feedbacks/users) ─────
const Activity = () => {
  const { users, feedbacks } = useData();

  const events = useMemo(() => {
    const evs = [];
    feedbacks.slice(0, 8).forEach(f => {
      const d = tsToDate(f.created_at);
      if (!d) return;
      evs.push({
        when: d, type: f.is_resolved ? "good" : (f.category === "bug" ? "warn" : "info"),
        text: <><b>{f.display_name || f.email || "Anonim"}</b> {f.category === "bug" ? "hata raporu bıraktı" : "geri bildirim gönderdi"} · <code>{f.platform || "ios"}{f.app_version ? ` · v${f.app_version}` : ""}</code></>
      });
    });
    [...users].sort((a, b) => {
      const ta = tsToDate(a.subscription_start)?.getTime() || 0;
      const tb = tsToDate(b.subscription_start)?.getTime() || 0;
      return tb - ta;
    }).filter(u => u.is_premium).slice(0, 4).forEach(u => {
      const d = tsToDate(u.subscription_start) || tsToDate(u.created_at);
      if (!d) return;
      evs.push({
        when: d, type: "good",
        text: <><b>{u.display_name || u.email || "Anonim"}</b> Premium aboneliğe geçti · <code>{u.subscription_plan || "—"}</code></>
      });
    });
    [...users].sort((a, b) => {
      const ta = tsToDate(a.created_at)?.getTime() || 0;
      const tb = tsToDate(b.created_at)?.getTime() || 0;
      return tb - ta;
    }).slice(0, 4).forEach(u => {
      const d = tsToDate(u.created_at);
      if (!d) return;
      evs.push({
        when: d, type: "info",
        text: <><b>{u.display_name || u.email || "Anonim"}</b> hesap oluşturdu · <code>{u.auth_provider || "—"}</code></>
      });
    });
    return evs.sort((a, b) => b.when - a.when).slice(0, 8);
  }, [users, feedbacks]);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Canlı aktivite</h3>
          <span className="panel-sub">Son sistem & kullanıcı olayları</span>
        </div>
      </div>
      <div className="panel-body">
        {events.length === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="sparkle" size={20} /></div>
            <div className="empty-title">Henüz olay yok</div>
            <div className="empty-sub">Kayıt ve geri bildirim olayları burada listelenecek.</div>
          </div>
        ) : (
          <div className="activity">
            {events.map((a, i) => (
              <div key={i} className="act-row">
                <div className={`act-dot ${a.type}`} />
                <div className="act-text">{a.text}</div>
                <span className="act-time">{fmtRelative(a.when)}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Pages ─────
const DashboardPage = ({ onNav }) => (
  <>
    <Hero />
    <Stats onNav={onNav} />
    <div className="two-col">
      <GrowthChart />
      <Funnel />
    </div>
    <div className="two-col">
      <RecentUsers onViewAll={() => onNav("users")} />
      <RecentFeedback onViewAll={() => onNav("feedback")} />
    </div>
    <Heatmap />
    <Activity />
  </>
);

// Data from users.json
const oldUsersToSync = [
  { uid: "6uyUwen6v1g2NrJ2MQqAnuCDkTJ2", email: "newkiwi0505@gmail.com", name: "Engin", created_at: 1774908032068, provider: "apple" },
  { uid: "8Goh6KV4afRZvcPZrVN8bD5Qvxj1", email: "newkiwi0514@gmail.com", name: "Engin Erdem", created_at: 1777838629751, provider: "google" },
  { uid: "B4ofwzAbBYULMmc3eV4FchA7o7q2", email: "destek@sleepora.app", name: "Destek", created_at: 1777788506860, provider: "email" },
  { uid: "ezp5SpFCHkfQANH3JydsWsCGmeg1", email: "newkiwi5555@gmail.com", name: "Engin Erdem", created_at: 1775068495346, provider: "google" }
];

// ───── Users page ─────
const UsersPage = () => {
  const { users, loading, refresh } = useData();
  const toast = useToast();
  const [q, setQ] = useState("");
  const [filter, setFilter] = useState("all");

  const handleSyncOldUsers = async () => {
    if (!window._fb || !window._fb.setDoc) {
      toast.push("Lütfen tarayıcınızı ZORLU YENİLEYİN (Cmd+Shift+R veya Ctrl+F5)", "error");
      return;
    }
    
    try {
      const { doc, setDoc, serverTimestamp } = window._fb;
      for (const u of oldUsersToSync) {
        await setDoc(doc(window._fbDb, "users", u.uid), {
          email: u.email,
          display_name: u.name,
          auth_provider: u.provider,
          created_at: new Date(u.created_at),
          last_login: serverTimestamp(),
          is_premium: false,
          baby_name: ''
        }, { merge: true });
      }
      refresh();
      toast.push("Eski üyeler başarıyla eşitlendi!", "success");
    } catch (e) {
      toast.push("Hata: " + e.message, "error");
    }
  };

  const handleTogglePremium = async (u) => {
    if (!window._fb || !window._fb.updateDoc) return;
    
    try {
      const { doc, updateDoc, serverTimestamp } = window._fb;
      await updateDoc(doc(window._fbDb, "users", u.id), {
        is_premium: !u.is_premium,
        subscription_plan: !u.is_premium ? "Admin Manuel" : null,
        subscription_start: !u.is_premium ? serverTimestamp() : null
      });
      refresh();
      toast.push("Premium durumu güncellendi!", "success");
    } catch (e) {
      toast.push("Hata: " + e.message, "error");
    }
  };

  const filtered = useMemo(() => {
    const ql = q.toLowerCase();
    return [...users]
      .filter(u => {
        const match = (u.email || "").toLowerCase().includes(ql) ||
                      (u.display_name || "").toLowerCase().includes(ql);
        if (!match) return false;
        if (filter === "premium") return u.is_premium;
        if (filter === "free") return !u.is_premium;
        if (filter === "apple") return u.auth_provider === "apple";
        if (filter === "google") return u.auth_provider === "google";
        return true;
      })
      .sort((a, b) => (tsToDate(b.created_at)?.getTime() || 0) - (tsToDate(a.created_at)?.getTime() || 0));
  }, [users, q, filter]);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Kullanıcılar</h3>
          <span className="panel-sub">{filtered.length} sonuç · {users.length} toplam</span>
        </div>
        <div className="panel-h-right" style={{ gap: 10 }}>
          <button 
            className="btn" 
            style={{ fontSize: 12, padding: "6px 12px", background: "var(--accent)", color: "white", borderRadius: 4, border: "none", cursor: "pointer", fontWeight: "bold" }} 
            onClick={handleSyncOldUsers}
          >
            Eski Üyeleri Eşitle
          </button>
          <div className="search" style={{ minWidth: 220 }}>
            <Icon name="search" size={14} />
            <input value={q} onChange={e => setQ(e.target.value)} placeholder="İsim veya e-posta ara…" />
          </div>
          <div className="seg">
            {[["all", "Tümü"], ["premium", "Premium"], ["free", "Ücretsiz"], ["apple", "Apple"], ["google", "Google"]].map(([k, l]) => (
              <button key={k} className={filter === k ? "on" : ""} onClick={() => setFilter(k)}>{l}</button>
            ))}
          </div>
        </div>
      </div>
      <div className="panel-body" style={{ padding: 0 }}>
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : filtered.length === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="users" size={20} /></div>
            <div className="empty-title">Kullanıcı bulunamadı</div>
            <div className="empty-sub">Filtre kriterlerinize uyan kullanıcı yok.</div>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
              <thead>
                <tr style={{ color: "var(--fg-2)", fontSize: 11, textTransform: "uppercase", letterSpacing: "0.06em" }}>
                  <th style={{ textAlign: "left", padding: "12px 20px", borderBottom: "1px solid var(--line)" }}>Kullanıcı</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Sağlayıcı</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Kayıt</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Son giriş</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Plan</th>
                  <th style={{ textAlign: "right", padding: "12px 20px", borderBottom: "1px solid var(--line)" }}>İşlem</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map(u => {
                  const hue = hueFromString(u.email || u.id);
                  return (
                    <tr key={u.id} style={{ borderBottom: "1px solid var(--line)" }}>
                      <td style={{ padding: "12px 20px" }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <div className="uavatar" style={{ background: `linear-gradient(135deg, oklch(0.65 0.14 ${hue}), oklch(0.45 0.14 var(--accent-h)))` }}>
                            {initials(u.display_name, u.email)}
                          </div>
                          <div>
                            <div className="uname">{u.display_name || "Anonim"}</div>
                            <div className="uemail">{u.email || u.id}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>
                        {u.auth_provider === "apple" ? <span style={{display: "flex", alignItems: "center", gap: 6}}><img src="assets/apple-logo.png" style={{width: 14, height: 14, filter: "invert(1)"}} /> Apple</span>
                          : u.auth_provider === "google" ? <span style={{display: "flex", alignItems: "center", gap: 6}}><img src="assets/google.png" style={{width: 14, height: 14}} /> Google</span>
                          : u.auth_provider === "email" ? <span style={{display: "flex", alignItems: "center", gap: 6}}><img src="assets/email.png" style={{width: 14, height: 14}} /> E-posta</span>
                          : u.auth_provider || "—"}
                      </td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>{fmtDate(u.created_at)}</td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>{fmtDate(u.last_login)}</td>
                      <td style={{ padding: "12px 12px" }}>
                        <span className={`ubadge ${u.is_premium ? "premium" : ""}`}>
                          {u.is_premium ? `★ ${u.subscription_plan || "Premium"}` : "Ücretsiz"}
                        </span>
                      </td>
                      <td style={{ padding: "12px 20px", textAlign: "right" }}>
                        <button 
                          onClick={() => handleTogglePremium(u)}
                          style={{
                            background: u.is_premium ? "oklch(0.3 0.05 15)" : "oklch(0.80 0.13 75)",
                            color: u.is_premium ? "var(--fg-1)" : "#fff",
                            border: "none", borderRadius: 4, padding: "5px 10px", fontSize: 11, cursor: "pointer", fontWeight: "bold",
                            minWidth: 85
                          }}
                        >
                          {u.is_premium ? "İptal Et" : "Premium Yap"}
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Premium page ─────
const PremiumPage = () => {
  const { users, loading } = useData();
  const premiums = useMemo(() => users.filter(u => u.is_premium)
    .sort((a, b) => (tsToDate(b.subscription_start)?.getTime() || 0) - (tsToDate(a.subscription_start)?.getTime() || 0)), [users]);

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Premium üyeler</h3>
          <span className="panel-sub">{premiums.length} aktif abonelik</span>
        </div>
      </div>
      <div className="panel-body" style={{ padding: 0 }}>
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : premiums.length === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="star" size={20} /></div>
            <div className="empty-title">Premium üye yok</div>
            <div className="empty-sub">Aboneliğe geçen kullanıcılar burada görünecek.</div>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
              <thead>
                <tr style={{ color: "var(--fg-2)", fontSize: 11, textTransform: "uppercase", letterSpacing: "0.06em" }}>
                  <th style={{ textAlign: "left", padding: "12px 20px", borderBottom: "1px solid var(--line)" }}>Kullanıcı</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Plan</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Başlangıç</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Bitiş</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Platform</th>
                </tr>
              </thead>
              <tbody>
                {premiums.map(u => {
                  const hue = hueFromString(u.email || u.id);
                  return (
                    <tr key={u.id} style={{ borderBottom: "1px solid var(--line)" }}>
                      <td style={{ padding: "12px 20px" }}>
                        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                          <div className="uavatar" style={{ background: `linear-gradient(135deg, oklch(0.65 0.14 ${hue}), oklch(0.45 0.14 var(--accent-h)))` }}>
                            {initials(u.display_name, u.email)}
                          </div>
                          <div>
                            <div className="uname">{u.display_name || "Anonim"}</div>
                            <div className="uemail">{u.email || u.id}</div>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: "12px 12px" }}>
                        <span className="ubadge premium">{u.subscription_plan || "—"}</span>
                      </td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>{fmtDate(u.subscription_start)}</td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>
                        {u.subscription_plan === "lifetime" ? "♾️ Ömür Boyu" : fmtDate(u.subscription_end)}
                      </td>
                      <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>{u.subscription_platform || "—"}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Feedback page ─────
const FeedbackPage = () => {
  const { feedbacks, setFeedbacks, loading } = useData();
  const toast = useToast();
  const [q, setQ] = useState("");
  const [cat, setCat] = useState("all");
  const [status, setStatus] = useState("all");

  const filtered = useMemo(() => {
    const ql = q.toLowerCase();
    return feedbacks.filter(f => {
      if (ql && !(f.message || "").toLowerCase().includes(ql) &&
                 !(f.display_name || "").toLowerCase().includes(ql) &&
                 !(f.email || "").toLowerCase().includes(ql)) return false;
      if (cat !== "all" && f.category !== cat) return false;
      if (status === "unread") return !f.is_read;
      if (status === "read") return f.is_read && !f.is_resolved;
      if (status === "resolved") return f.is_resolved;
      return true;
    });
  }, [feedbacks, q, cat, status]);

  const update = async (id, patch) => {
    try {
      const { doc, updateDoc } = window._fb;
      await updateDoc(doc(window._fbDb, "feedbacks", id), patch);
      setFeedbacks(fbs => fbs.map(f => f.id === id ? { ...f, ...patch } : f));
      toast.push("Güncellendi", "success");
    } catch (e) { toast.push(e.message || "Güncellenemedi", "error"); }
  };

  const remove = async (id) => {
    if (!confirm("Bu geri bildirimi silmek istediğinizden emin misiniz?")) return;
    try {
      const { doc, deleteDoc } = window._fb;
      await deleteDoc(doc(window._fbDb, "feedbacks", id));
      setFeedbacks(fbs => fbs.filter(f => f.id !== id));
      toast.push("Silindi", "error");
    } catch (e) { toast.push(e.message || "Silinemedi", "error"); }
  };

  const catLabel = (c) => c === "bug" ? "🐛 Hata" : c === "suggestion" ? "💡 Öneri" : "💬 Genel";

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Geri bildirimler</h3>
          <span className="panel-sub">{filtered.length} sonuç · {feedbacks.length} toplam</span>
        </div>
        <div className="panel-h-right" style={{ gap: 10, flexWrap: "wrap" }}>
          <div className="search" style={{ minWidth: 200 }}>
            <Icon name="search" size={14} />
            <input value={q} onChange={e => setQ(e.target.value)} placeholder="Mesaj, isim ara…" />
          </div>
          <div className="seg">
            {[["all", "Tümü"], ["bug", "Hata"], ["suggestion", "Öneri"], ["general", "Genel"]].map(([k, l]) => (
              <button key={k} className={cat === k ? "on" : ""} onClick={() => setCat(k)}>{l}</button>
            ))}
          </div>
          <div className="seg">
            {[["all", "Tümü"], ["unread", "Okunmamış"], ["read", "Okundu"], ["resolved", "Çözüldü"]].map(([k, l]) => (
              <button key={k} className={status === k ? "on" : ""} onClick={() => setStatus(k)}>{l}</button>
            ))}
          </div>
        </div>
      </div>
      <div className="panel-body">
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : filtered.length === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="chat" size={20} /></div>
            <div className="empty-title">Geri bildirim bulunamadı</div>
            <div className="empty-sub">Filtre kriterlerinize uygun yorum yok.</div>
          </div>
        ) : (
          <div>
            {filtered.map(f => {
              const hue = hueFromString(f.email || f.id);
              const name = f.display_name || f.email || "Anonim";
              return (
                <div key={f.id} style={{
                  padding: 16, marginBottom: 10, border: "1px solid var(--line)",
                  borderRadius: 10, background: "var(--bg-2)",
                  borderLeft: !f.is_read ? "3px solid var(--accent)" : f.is_resolved ? "3px solid var(--good)" : "1px solid var(--line)"
                }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
                    <div className="uavatar" style={{ width: 28, height: 28, fontSize: 11, background: `linear-gradient(135deg, oklch(0.65 0.14 ${hue}), oklch(0.45 0.14 var(--accent-h)))` }}>
                      {initials(name)}
                    </div>
                    <div className="fb-author">{name}</div>
                    <span className="ubadge" style={{ fontSize: 10 }}>{catLabel(f.category)}</span>
                    {!f.is_read && <span className="ubadge new" style={{ fontSize: 10 }}>Yeni</span>}
                    {f.is_resolved && <span className="ubadge" style={{ fontSize: 10, color: "var(--good)", borderColor: "oklch(0.78 0.12 155 / 0.32)", background: "oklch(0.78 0.12 155 / 0.08)" }}>✓ Çözüldü</span>}
                    <span className="fb-tag" style={{ marginLeft: "auto" }}>{fmtDate(f.created_at)} · {f.platform || "ios"}{f.app_version ? ` · v${f.app_version}` : ""}</span>
                  </div>
                  <div className="fb-text" style={{ marginBottom: 10 }}>{f.message || "—"}</div>
                  <div style={{ display: "flex", gap: 6 }}>
                    {!f.is_read && (
                      <button className="panel-action" onClick={() => update(f.id, { is_read: true })}>
                        <Icon name="check" size={12} /> Okundu işaretle
                      </button>
                    )}
                    {!f.is_resolved && (
                      <button className="panel-action" onClick={() => update(f.id, { is_read: true, is_resolved: true })}>
                        <Icon name="check" size={12} /> Çözüldü
                      </button>
                    )}
                    <button className="panel-action" style={{ color: "var(--bad)", borderColor: "oklch(0.72 0.16 25 / 0.3)" }} onClick={() => remove(f.id)}>
                      <Icon name="trash" size={12} /> Sil
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Leaderboard page ─────
const LeaderboardPage = () => {
  const [game, setGame] = useState("2048");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const toast = useToast();

  const games = [
    { id: "2048",         label: "2048" },
    { id: "block_puzzle", label: "Blok Bulmaca" },
    { id: "quiz",         label: "Bilgi Yarışması" },
    { id: "minesweeper",  label: "Mayın Tarlası" },
  ];

  const load = useCallback(async () => {
    if (!window._fbDb || !window._fb) return;
    setLoading(true);
    try {
      const { collection, getDocs, query, orderBy, limit } = window._fb;
      const higher = game !== "minesweeper";
      const snap = await getDocs(query(
        collection(window._fbDb, "leaderboards", game, "scores"),
        orderBy("score", higher ? "desc" : "asc"),
        limit(50)
      ));
      setRows(snap.docs.map((d, i) => ({ rank: i + 1, id: d.id, ...d.data() })));
    } catch (e) {
      console.error(e);
      setRows([]);
    } finally { setLoading(false); }
  }, [game]);

  useEffect(() => { load(); }, [load]);

  const remove = async (id) => {
    if (!confirm("Bu skoru silmek istediğinizden emin misiniz?")) return;
    try {
      const { doc, deleteDoc } = window._fb;
      await deleteDoc(doc(window._fbDb, "leaderboards", game, "scores", id));
      load();
      toast.push("Skor silindi", "error");
    } catch (e) { toast.push(e.message || "Silinemedi", "error"); }
  };

  return (
    <div className="panel">
      <div className="panel-h">
        <div className="panel-h-left">
          <h3 className="panel-title">Lider tablosu</h3>
          <span className="panel-sub">{loading ? "Yükleniyor…" : `${rows.length} skor`}</span>
        </div>
        <div className="panel-h-right">
          <div className="seg">
            {games.map(g => (
              <button key={g.id} className={game === g.id ? "on" : ""} onClick={() => setGame(g.id)}>{g.label}</button>
            ))}
          </div>
        </div>
      </div>
      <div className="panel-body" style={{ padding: 0 }}>
        {loading ? (
          <div className="empty"><div className="empty-sub">Yükleniyor…</div></div>
        ) : rows.length === 0 ? (
          <div className="empty">
            <div className="empty-glyph"><Icon name="bar" size={20} /></div>
            <div className="empty-title">Skor bulunamadı</div>
            <div className="empty-sub">Bu oyun için henüz kayıtlı skor yok.</div>
          </div>
        ) : (
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
              <thead>
                <tr style={{ color: "var(--fg-2)", fontSize: 11, textTransform: "uppercase", letterSpacing: "0.06em" }}>
                  <th style={{ textAlign: "left", padding: "12px 20px", borderBottom: "1px solid var(--line)" }}>#</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>İsim</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Skor</th>
                  <th style={{ textAlign: "left", padding: "12px 12px", borderBottom: "1px solid var(--line)" }}>Tarih</th>
                  <th style={{ textAlign: "right", padding: "12px 20px", borderBottom: "1px solid var(--line)" }}>İşlem</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(r => (
                  <tr key={r.id} style={{ borderBottom: "1px solid var(--line)" }}>
                    <td style={{ padding: "12px 20px", fontFamily: "Geist Mono, monospace", color: "var(--fg-1)" }}>
                      {r.rank <= 3 ? ["🥇", "🥈", "🥉"][r.rank - 1] : r.rank}
                    </td>
                    <td style={{ padding: "12px 12px" }}>{r.display_name || "Anonim"}</td>
                    <td style={{ padding: "12px 12px", fontWeight: 600 }}>{(r.score ?? 0).toLocaleString("tr-TR")}</td>
                    <td style={{ padding: "12px 12px", color: "var(--fg-1)" }}>{fmtDate(r.updated_at)}</td>
                    <td style={{ padding: "12px 20px", textAlign: "right" }}>
                      <button className="panel-action" style={{ color: "var(--bad)", borderColor: "oklch(0.72 0.16 25 / 0.3)" }} onClick={() => remove(r.id)}>
                        <Icon name="trash" size={12} /> Sil
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

// ───── Sleep page (no real data yet) ─────
const SleepPage = () => (
  <div className="panel">
    <div className="panel-h">
      <div className="panel-h-left">
        <h3 className="panel-title">Uyku verileri</h3>
        <span className="panel-sub">Toplu uyku raporları</span>
      </div>
    </div>
    <div className="panel-body">
      <div className="empty" style={{ padding: 60 }}>
        <div className="empty-glyph"><Icon name="moon" size={20} /></div>
        <div className="empty-title">Uyku verisi entegrasyonu hazır değil</div>
        <div className="empty-sub">
          Sleepora uygulaması uyku oturumlarını Firestore'a yazmaya başladığında bu panel
          otomatik olarak doluyor olacak. Şu an için kayıtlı oturum yok.
        </div>
      </div>
    </div>
  </div>
);

// ───── Settings page ─────
const SettingsPage = () => {
  const { metrics, refresh, loading } = useData();
  const toast = useToast();
  const adminEmail = window._fbUser?.email || "—";
  const adminUid = window._fbUser?.uid || "—";

  const [displayName, setDisplayName] = useState(window._fbUser?.displayName || "");
  const [nameInput, setNameInput] = useState(window._fbUser?.displayName || "");
  const [savingName, setSavingName] = useState(false);

  const handleSaveName = async () => {
    if (!nameInput.trim()) return;
    setSavingName(true);
    try {
      const { updateProfile } = await import("https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js");
      await updateProfile(window._fbUser, { displayName: nameInput.trim() });
      setDisplayName(nameInput.trim());
      // Update sidebar footer name without reload
      if (window._fbUser) window._fbUser.displayName = nameInput.trim();
      toast.push("Admin adı güncellendi ✓", "success");
    } catch (e) {
      toast.push(e.message || "Ad güncellenemedi", "error");
    } finally {
      setSavingName(false);
    }
  };

  return (
    <>
      {/* Admin name edit card */}
      <div className="panel">
        <div className="panel-h">
          <div className="panel-h-left">
            <h3 className="panel-title">Admin profili</h3>
            <span className="panel-sub">Görünen adınızı değiştirin</span>
          </div>
        </div>
        <div className="panel-body">
          <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 18 }}>
            <img src="logo.jpg" alt="Sleepora" style={{ width: 52, height: 52, borderRadius: 14, objectFit: "cover", border: "1px solid var(--line-2)", boxShadow: "0 4px 16px rgba(0,0,0,0.4)" }} />
            <div>
              <div style={{ fontSize: 16, fontWeight: 600, color: "var(--fg-0)", marginBottom: 2 }}>{displayName || "Admin"}</div>
              <div style={{ fontSize: 12, color: "var(--fg-2)", fontFamily: "Geist Mono, monospace" }}>{adminEmail}</div>
            </div>
          </div>
          <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <div className="search" style={{ flex: 1, maxWidth: 360 }}>
              <Icon name="users" size={14} />
              <input
                value={nameInput}
                onChange={e => setNameInput(e.target.value)}
                onKeyDown={e => e.key === "Enter" && handleSaveName()}
                placeholder="Yeni admin adı…"
              />
            </div>
            <button
              className="panel-action"
              onClick={handleSaveName}
              disabled={savingName || !nameInput.trim() || nameInput.trim() === displayName}
              style={{ opacity: (savingName || !nameInput.trim() || nameInput.trim() === displayName) ? 0.5 : 1 }}
            >
              <Icon name="check" size={13} /> {savingName ? "Kaydediliyor…" : "Kaydet"}
            </button>
          </div>
        </div>
      </div>

      {/* System info card */}
      <div className="panel">
        <div className="panel-h">
          <div className="panel-h-left">
            <h3 className="panel-title">Hesap & sistem</h3>
            <span className="panel-sub">Oturum açan yönetici bilgileri</span>
          </div>
          <div className="panel-h-right">
            <button className="panel-action" onClick={refresh} disabled={loading}>
              <Icon name="refresh" size={13} /> Verileri yenile
            </button>
          </div>
        </div>
        <div className="panel-body">
          <div className="detail-grid" style={{ display: "grid", gridTemplateColumns: "repeat(2, 1fr)", gap: 14 }}>
            {[
              ["E-posta", adminEmail],
              ["UID", adminUid],
              ["Toplam kullanıcı", metrics.total.toLocaleString("tr-TR")],
              ["Toplam premium", metrics.premium.toLocaleString("tr-TR")],
              ["Toplam geri bildirim", metrics.feedbackTotal.toLocaleString("tr-TR")],
              ["Okunmamış", metrics.unread.toLocaleString("tr-TR")],
              ["Aktif (7g)", metrics.activeWeek.toLocaleString("tr-TR")],
              ["Onboarding tamamlanan", metrics.onboarded.toLocaleString("tr-TR")],
            ].map(([l, v], i) => (
              <div key={i} style={{ background: "var(--bg-2)", border: "1px solid var(--line)", borderRadius: 10, padding: 14 }}>
                <div style={{ fontSize: 11, color: "var(--fg-2)", textTransform: "uppercase", letterSpacing: "0.06em", marginBottom: 6 }}>{l}</div>
                <div style={{ fontSize: 14, color: "var(--fg-0)", fontFamily: l === "UID" ? "Geist Mono, monospace" : "inherit", wordBreak: "break-all" }}>{v}</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 18, padding: 14, background: "var(--bg-2)", border: "1px dashed var(--line-2)", borderRadius: 10, fontSize: 12.5, color: "var(--fg-1)", lineHeight: 1.6 }}>
            <b style={{ color: "var(--fg-0)" }}>Not:</b> Tema ve yerleşim ayarları ekranın sağ alt köşesindeki
            <i> Tweaks </i> panelinden değiştirilebilir. Veriler doğrudan Firebase Firestore'dan okunur ve
            yenile butonuna basıldığında tekrar çekilir.
          </div>
        </div>
      </div>
    </>
  );
};

// ───── Tweaks ─────
const Tweaks = () => {
  const [tweaks, setTweak] = window.useTweaks(TWEAK_DEFAULTS);

  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--accent-h", tweaks.accentHue);
    root.style.setProperty("--r-lg", tweaks.radius + "px");
    document.body.dataset.density = tweaks.density;
    document.body.dataset.sidebar = tweaks.sidebar;
  }, [tweaks]);

  const { TweaksPanel, TweakSection, TweakSlider, TweakRadio } = window;

  return (
    <TweaksPanel>
      <TweakSection title="Görünüm">
        <TweakSlider label="Aksan rengi (hue)" value={tweaks.accentHue} min={0} max={360} step={1} onChange={(v) => setTweak("accentHue", v)} suffix="°" />
        <TweakSlider label="Köşe yuvarlama" value={tweaks.radius} min={0} max={24} step={1} onChange={(v) => setTweak("radius", v)} suffix="px" />
      </TweakSection>
      <TweakSection title="Yerleşim">
        <TweakRadio label="Yoğunluk" value={tweaks.density} options={[
          { value: "compact", label: "Sıkı" },
          { value: "default", label: "Normal" },
          { value: "comfortable", label: "Geniş" },
        ]} onChange={(v) => setTweak("density", v)} />
        <TweakRadio label="Kenar çubuğu" value={tweaks.sidebar} options={[
          { value: "expanded", label: "Genişletilmiş" },
          { value: "collapsed", label: "Daraltılmış" },
        ]} onChange={(v) => setTweak("sidebar", v)} />
      </TweakSection>
    </TweaksPanel>
  );
};

// ───── Shell ─────
const Shell = () => {
  const [page, setPage] = useState("dash");
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { refresh, error } = useData();

  const navigate = useCallback((id) => {
    setPage(id);
    setSidebarOpen(false); // close sidebar on mobile after navigation
  }, []);

  const renderPage = () => {
    switch (page) {
      case "dash":        return <DashboardPage onNav={navigate} />;
      case "users":       return <UsersPage />;
      case "premium":     return <PremiumPage />;
      case "feedback":    return <FeedbackPage />;
      case "leaderboard": return <LeaderboardPage />;
      case "sleep":       return <SleepPage />;
      case "settings":    return <SettingsPage />;
      default:            return <DashboardPage onNav={navigate} />;
    }
  };

  return (
    <>
      <div className="app">
        {/* Mobile backdrop */}
        <div
          className={`sidebar-backdrop ${sidebarOpen ? "open" : ""}`}
          onClick={() => setSidebarOpen(false)}
        />
        <Sidebar page={page} onNavigate={navigate} mobileOpen={sidebarOpen} />
        <main className="main">
          <Topbar page={page} onRefresh={refresh} onMenuToggle={() => setSidebarOpen(o => !o)} />
          <div className="content">
            {error && (
              <div style={{ padding: 14, background: "oklch(0.72 0.16 25 / 0.08)", border: "1px solid oklch(0.72 0.16 25 / 0.3)", borderRadius: 10, color: "var(--bad)", fontSize: 13 }}>
                Veri yükleme hatası: {error}
              </div>
            )}
            {renderPage()}
            <div style={{ textAlign: "center", color: "var(--fg-3)", fontSize: 11, padding: "20px 0", fontFamily: "Geist Mono, monospace" }}>
              SLEEPORA · ADMIN · v3.4.2 · {new Date().getFullYear()}
            </div>
          </div>
        </main>
      </div>
      <Tweaks />
    </>
  );
};

const App = () => (
  <DataProvider>
    <ToastProvider>
      <Shell />
    </ToastProvider>
  </DataProvider>
);

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
