import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js";
import { getAuth, signInWithEmailAndPassword, signOut, onAuthStateChanged }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-auth.js";
import { getFirestore, collection, getDocs, doc, updateDoc, deleteDoc,
  query, orderBy, limit, where, Timestamp }
  from "https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js";

const firebaseConfig = {
  apiKey: "AIzaSyDzN78BX_NBDjgTsl64wnTZrDdD9n3Dx-A",
  authDomain: "sleepora-89902.firebaseapp.com",
  projectId: "sleepora-89902",
  storageBucket: "sleepora-89902.firebasestorage.app",
  messagingSenderId: "461986109206",
  appId: "1:461986109206:ios:6094dd2d4efb626896a237"
};

const app  = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db   = getFirestore(app);

// ── Admin UID whitelist ──
const ADMIN_UIDS = ["B4ofwzAbBYULMmc3eV4FchA7o7q2"]; // destek@sleepora.app

// ── State ──
let allUsers    = [];
let allFeedback = [];
let currentPremiumUid = null;

// ── Init ──
onAuthStateChanged(auth, async user => {
  if (user) {
    if (ADMIN_UIDS.length > 0 && !ADMIN_UIDS.includes(user.uid)) {
      console.warn("Admin yetkisi yok:", user.uid);
      await signOut(auth); return;
    }
    // UI element updates (only if elements exist — for both old and new panel)
    const adminUserInfo = document.getElementById("adminUserInfo");
    if (adminUserInfo) adminUserInfo.textContent = user.email;

    try {
      await loadDashboard();
      renderUsers(allUsers);
      renderPremium(allUsers);
      renderFeedback(allFeedback);
    } catch(e) {
      console.error("Veri yükleme hatası:", e);
    }
  }
});


// ── Clock ──
setInterval(() => {
  document.getElementById("currentTime").textContent =
    new Date().toLocaleString("tr-TR", { day:"2-digit", month:"short", hour:"2-digit", minute:"2-digit" });
}, 1000);

// ─────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────
window.doLogin = async function() {
  const email = document.getElementById("loginEmail").value.trim();
  const pass  = document.getElementById("loginPassword").value;
  const errEl = document.getElementById("loginError");
  const btn   = document.getElementById("loginBtn");
  const txt   = document.getElementById("loginBtnText");
  const spin  = document.getElementById("loginSpinner");
  errEl.classList.add("hidden");
  txt.textContent = "Giriş yapılıyor…"; spin.classList.remove("hidden"); btn.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, email, pass);
  } catch(e) {
    errEl.textContent = e.code === "auth/invalid-credential"
      ? "E-posta veya şifre hatalı." : e.message;
    errEl.classList.remove("hidden");
    txt.textContent = "Giriş Yap"; spin.classList.add("hidden"); btn.disabled = false;
  }
};

window.doLogout = async function() {
  await signOut(auth);
};

document.getElementById("loginPassword")?.addEventListener("keydown", e => {
  if (e.key === "Enter") window.doLogin();
});

// ─────────────────────────────────────────
// NAVIGATION
// ─────────────────────────────────────────
const pageTitles = { dashboard:"Dashboard", users:"Kullanıcılar",
  premium:"Premium", feedback:"Geri Bildirimler", leaderboard:"Leaderboard" };

window.navigateTo = function(page) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
  document.querySelectorAll(".nav-item").forEach(n => n.classList.remove("active"));
  document.getElementById(`page-${page}`).classList.add("active");
  document.querySelector(`[data-page="${page}"]`).classList.add("active");
  document.getElementById("pageTitle").textContent = pageTitles[page] || page;
  document.getElementById("sidebar").classList.remove("open");
  if (page === "leaderboard") loadLeaderboard();
};

window.toggleSidebar = function() {
  document.getElementById("sidebar").classList.toggle("open");
};

// ─────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────
function fmtDate(ts) {
  if (!ts) return "–";
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString("tr-TR", { day:"2-digit", month:"short", year:"numeric" });
}

function avatarColor(str) {
  const colors = ["#7C3AED","#0891B2","#059669","#D97706","#DB2777","#DC2626"];
  let h = 0;
  for (const c of (str||"?")) h = (h * 31 + c.charCodeAt(0)) & 0xffff;
  return colors[h % colors.length];
}

function initials(name, email) {
  const src = name || email || "?";
  return src.slice(0,2).toUpperCase();
}

window.showToast = function(msg, type="success") {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.className = `toast ${type}`;
  t.classList.remove("hidden");
  setTimeout(() => t.classList.add("hidden"), 3000);
};

// ─────────────────────────────────────────
// DASHBOARD
// ─────────────────────────────────────────
async function loadDashboard() {
  const usersSnap    = await getDocs(collection(db, "users"));
  const feedbackSnap = await getDocs(query(collection(db, "feedbacks"), orderBy("created_at","desc")));

  allUsers    = usersSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  allFeedback = feedbackSnap.docs.map(d => ({ id: d.id, ...d.data() }));

  const premiumCount = allUsers.filter(u => u.is_premium).length;
  const unread       = allFeedback.filter(f => !f.is_read).length;
  const conv         = allUsers.length > 0
    ? ((premiumCount / allUsers.length) * 100).toFixed(1) + "%" : "–";

  document.getElementById("statTotalUsers").textContent   = allUsers.length;
  document.getElementById("statPremiumUsers").textContent = premiumCount;
  document.getElementById("statFeedbacks").textContent    = allFeedback.length;
  document.getElementById("statConversion").textContent   = conv;
  document.getElementById("usersCountBadge").textContent  = allUsers.length;
  document.getElementById("premiumCountBadge").textContent= premiumCount;
  document.getElementById("feedbackCountBadge").textContent = unread > 0 ? unread : allFeedback.length;

  // Recent users
  const recent5 = [...allUsers].sort((a,b) => {
    const ta = a.created_at?.toDate?.() || new Date(0);
    const tb = b.created_at?.toDate?.() || new Date(0);
    return tb - ta;
  }).slice(0, 5);

  document.getElementById("recentUsersList").innerHTML = recent5.length
    ? recent5.map(u => `
      <div style="display:flex;align-items:center;gap:10px;padding:10px 20px;border-bottom:1px solid rgba(255,255,255,0.04)">
        <div class="user-avatar" style="background:${avatarColor(u.email)}">${initials(u.display_name,u.email)}</div>
        <div>
          <div style="font-size:13px;font-weight:600">${u.display_name||"Anonim"}</div>
          <div style="font-size:11px;color:var(--text3)">${u.email||u.id}</div>
        </div>
        <span class="badge ${u.is_premium?'premium':'free'}" style="margin-left:auto">
          ${u.is_premium?"✦ Premium":"Ücretsiz"}
        </span>
      </div>`).join("")
    : '<div class="list-placeholder">Kullanıcı bulunamadı.</div>';

  // Recent feedback
  const recent3fb = allFeedback.slice(0,3);
  document.getElementById("recentFeedbackList").innerHTML = recent3fb.length
    ? recent3fb.map(f => `
      <div style="padding:12px 20px;border-bottom:1px solid rgba(255,255,255,0.04)">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
          <span class="badge ${f.category||'general'}">${catLabel(f.category)}</span>
          ${!f.is_read ? '<span class="badge unread">Yeni</span>' : ''}
          <span style="font-size:11px;color:var(--text3);margin-left:auto">${fmtDate(f.created_at)}</span>
        </div>
        <div style="font-size:13px;color:var(--text2)">${(f.message||"").slice(0,100)}${f.message?.length>100?"…":""}</div>
      </div>`).join("")
    : '<div class="list-placeholder">Geri bildirim bulunamadı.</div>';
}

// ─────────────────────────────────────────
// USERS
// ─────────────────────────────────────────
function renderUsers(users) {
  const body = document.getElementById("usersTableBody");
  if (!users.length) { body.innerHTML = `<tr><td colspan="6" class="loading-row">Kullanıcı bulunamadı.</td></tr>`; return; }
  body.innerHTML = users.map(u => `
    <tr>
      <td>
        <div class="user-cell">
          <div class="user-avatar" style="background:${avatarColor(u.email)}">${initials(u.display_name,u.email)}</div>
          <div>
            <div class="user-name">${u.display_name||"Anonim"}</div>
            <div class="user-email">${u.email||u.id}</div>
          </div>
        </div>
      </td>
      <td><span class="badge ${u.auth_provider||''}">
        ${u.auth_provider==="apple"?"🍎 Apple":u.auth_provider==="google"?"🟢 Google":"–"}
      </span></td>
      <td>${fmtDate(u.created_at)}</td>
      <td>${fmtDate(u.last_login)}</td>
      <td><span class="badge ${u.is_premium?'premium':'free'}">${u.is_premium?"✦ Premium":"Ücretsiz"}</span></td>
      <td style="display:flex;gap:6px;flex-wrap:wrap">
        <button class="action-btn purple" onclick="openUserModal('${u.id}')">Detay</button>
        <button class="action-btn teal"   onclick="openPremiumModal('${u.id}')">Premium</button>
      </td>
    </tr>`).join("");
}

window.filterUsers = function() {
  const q      = document.getElementById("userSearch").value.toLowerCase();
  const filter = document.getElementById("userFilter").value;
  let list = allUsers.filter(u => {
    const match = (u.email||"").toLowerCase().includes(q) ||
                  (u.display_name||"").toLowerCase().includes(q);
    if (!match) return false;
    if (filter === "premium") return u.is_premium;
    if (filter === "free")    return !u.is_premium;
    if (filter === "apple")   return u.auth_provider === "apple";
    if (filter === "google")  return u.auth_provider === "google";
    return true;
  });
  renderUsers(list);
};

// ─────────────────────────────────────────
// PREMIUM
// ─────────────────────────────────────────
function renderPremium(users) {
  const premiums = users.filter(u => u.is_premium);
  document.getElementById("premiumTableBody").innerHTML = premiums.length
    ? premiums.map(u => `
      <tr>
        <td>
          <div class="user-cell">
            <div class="user-avatar" style="background:${avatarColor(u.email)}">${initials(u.display_name,u.email)}</div>
            <div>
              <div class="user-name">${u.display_name||"Anonim"}</div>
              <div class="user-email">${u.email||u.id}</div>
            </div>
          </div>
        </td>
        <td><span class="badge ${u.subscription_plan==='lifetime'?'lifetime':'premium'}">${u.subscription_plan||"–"}</span></td>
        <td>${fmtDate(u.subscription_start)}</td>
        <td>${u.subscription_plan==="lifetime"?"♾️ Ömür Boyu":fmtDate(u.subscription_end)}</td>
        <td>${u.subscription_platform||"–"}</td>
        <td><button class="action-btn purple" onclick="openPremiumModal('${u.id}')">Düzenle</button></td>
      </tr>`).join("")
    : `<tr><td colspan="6" class="loading-row">Premium üye bulunamadı.</td></tr>`;
}

window.filterPremium = function() {
  const q      = document.getElementById("premiumSearch").value.toLowerCase();
  const plan   = document.getElementById("premiumPlanFilter").value;
  let list = allUsers.filter(u => {
    if (!u.is_premium) return false;
    const match = (u.email||"").toLowerCase().includes(q) || (u.display_name||"").toLowerCase().includes(q);
    if (!match) return false;
    if (plan !== "all") return u.subscription_plan === plan;
    return true;
  });
  renderPremium(list);
};

// ── Premium Modal ──
window.openPremiumModal = function(uid) {
  currentPremiumUid = uid;
  const u = allUsers.find(x => x.id === uid);
  if (!u) return;
  document.getElementById("premiumModalUserInfo").innerHTML =
    `<strong>${u.display_name||"Anonim"}</strong> &mdash; <span style="color:var(--text3)">${u.email||uid}</span>`;
  const today = new Date().toISOString().split("T")[0];
  const end30 = new Date(Date.now()+30*86400000).toISOString().split("T")[0];
  document.getElementById("pmStart").value = today;
  document.getElementById("pmEnd").value   = end30;
  if (u.subscription_plan) document.getElementById("pmPlan").value = u.subscription_plan;
  document.getElementById("pmError").classList.add("hidden");
  document.getElementById("premiumModal").classList.remove("hidden");
};
window.closePremiumModal = function(e) {
  if (!e || e.target === document.getElementById("premiumModal"))
    document.getElementById("premiumModal").classList.add("hidden");
};

window.grantPremium = async function() {
  if (!currentPremiumUid) return;
  const plan  = document.getElementById("pmPlan").value;
  const start = document.getElementById("pmStart").value;
  const end   = document.getElementById("pmEnd").value;
  const spin  = document.getElementById("pmSpinner");
  const txt   = document.getElementById("pmBtnText");
  spin.classList.remove("hidden"); txt.textContent="Kaydediliyor…";
  try {
    const data = {
      is_premium: true,
      subscription_plan: plan,
      subscription_platform: "admin",
      subscription_start: start ? Timestamp.fromDate(new Date(start)) : null,
      subscription_end: plan === "lifetime" ? null : (end ? Timestamp.fromDate(new Date(end)) : null),
    };
    await updateDoc(doc(db,"users",currentPremiumUid), data);
    const idx = allUsers.findIndex(u => u.id === currentPremiumUid);
    if (idx !== -1) allUsers[idx] = { ...allUsers[idx], ...data };
    renderUsers(allUsers); renderPremium(allUsers);
    document.getElementById("premiumModal").classList.add("hidden");
    showToast("✦ Premium başarıyla verildi!", "success");
  } catch(e) {
    document.getElementById("pmError").textContent = e.message;
    document.getElementById("pmError").classList.remove("hidden");
  }
  spin.classList.add("hidden"); txt.textContent="✦ Premium Ver";
};

window.revokePremium = async function() {
  if (!currentPremiumUid || !confirm("Bu kullanıcının premiumunu iptal etmek istediğinizden emin misiniz?")) return;
  try {
    await updateDoc(doc(db,"users",currentPremiumUid), {
      is_premium: false, subscription_plan: null,
      subscription_end: null, subscription_start: null,
    });
    const idx = allUsers.findIndex(u => u.id === currentPremiumUid);
    if (idx !== -1) allUsers[idx].is_premium = false;
    renderUsers(allUsers); renderPremium(allUsers);
    document.getElementById("premiumModal").classList.add("hidden");
    showToast("Premium iptal edildi.", "error");
  } catch(e) { showToast(e.message, "error"); }
};

// ─────────────────────────────────────────
// USER DETAIL MODAL
// ─────────────────────────────────────────
window.openUserModal = function(uid) {
  const u = allUsers.find(x => x.id === uid);
  if (!u) return;
  document.getElementById("modalUserName").textContent = u.display_name || u.email || "Kullanıcı";
  document.getElementById("modalContent").innerHTML = `
    <div style="display:flex;align-items:center;gap:14px;margin-bottom:20px">
      <div class="user-avatar" style="background:${avatarColor(u.email)};width:52px;height:52px;font-size:18px;border-radius:16px">
        ${initials(u.display_name,u.email)}
      </div>
      <div>
        <div style="font-size:16px;font-weight:700">${u.display_name||"Anonim"}</div>
        <div style="font-size:12px;color:var(--text3)">${u.email||"–"}</div>
        <div style="margin-top:6px"><span class="badge ${u.is_premium?'premium':'free'}">${u.is_premium?"✦ Premium":"Ücretsiz"}</span></div>
      </div>
    </div>
    <div class="detail-grid">
      <div class="detail-item"><div class="detail-label">UID</div><div class="detail-value" style="font-size:11px">${u.id}</div></div>
      <div class="detail-item"><div class="detail-label">Giriş Tipi</div><div class="detail-value">${u.auth_provider||"–"}</div></div>
      <div class="detail-item"><div class="detail-label">Kayıt Tarihi</div><div class="detail-value">${fmtDate(u.created_at)}</div></div>
      <div class="detail-item"><div class="detail-label">Son Giriş</div><div class="detail-value">${fmtDate(u.last_login)}</div></div>
      <div class="detail-item"><div class="detail-label">Plan</div><div class="detail-value">${u.subscription_plan||"–"}</div></div>
      <div class="detail-item"><div class="detail-label">Platform</div><div class="detail-value">${u.subscription_platform||"–"}</div></div>
      <div class="detail-item"><div class="detail-label">Bebek Adı</div><div class="detail-value">${u.baby_name||"–"}</div></div>
      <div class="detail-item"><div class="detail-label">Oturum Sayısı</div><div class="detail-value">${u.session_count||0}</div></div>
    </div>
    <div style="margin-top:16px;display:flex;gap:8px">
      <button class="action-btn teal" style="flex:1" onclick="openPremiumModal('${u.id}');closeUserModal()">Premium Düzenle</button>
    </div>`;
  document.getElementById("userModal").classList.remove("hidden");
};
window.closeUserModal = function(e) {
  if (!e || e.target === document.getElementById("userModal"))
    document.getElementById("userModal").classList.add("hidden");
};

// ─────────────────────────────────────────
// FEEDBACK
// ─────────────────────────────────────────
function catLabel(cat) {
  return cat==="bug"?"🐛 Hata":cat==="suggestion"?"💡 Öneri":"💬 Genel";
}

async function loadFeedback() {
  if (allFeedback.length === 0) {
    const snap = await getDocs(query(collection(db,"feedbacks"), orderBy("created_at","desc")));
    allFeedback = snap.docs.map(d => ({ id:d.id, ...d.data() }));
  }
  renderFeedback(allFeedback);
}

function renderFeedback(list) {
  const el = document.getElementById("feedbackList");
  if (!list.length) { el.innerHTML = '<div class="list-placeholder">Geri bildirim bulunamadı.</div>'; return; }
  el.innerHTML = list.map(f => `
    <div class="feedback-card ${!f.is_read?'unread':''} ${f.is_resolved?'resolved':''}" id="fb-${f.id}">
      <div class="feedback-card-header">
        <div class="feedback-meta">
          <span class="badge ${f.category||'general'}">${catLabel(f.category)}</span>
          ${!f.is_read?'<span class="badge unread">Yeni</span>':''}
          ${f.is_resolved?'<span class="badge resolved">✓ Çözüldü</span>':''}
          <span style="font-size:12px;color:var(--text3)">${f.display_name||f.email||"Anonim"}</span>
        </div>
        <div class="feedback-actions">
          ${!f.is_read?`<button class="action-btn green" onclick="markRead('${f.id}')">Okundu</button>`:''}
          ${!f.is_resolved?`<button class="action-btn teal" onclick="markResolved('${f.id}')">Çözüldü</button>`:''}
          <button class="action-btn red" onclick="deleteFeedback('${f.id}')">Sil</button>
        </div>
      </div>
      <div class="feedback-msg">${f.message||""}</div>
      <div class="feedback-footer">${fmtDate(f.created_at)} · ${f.platform||"ios"} · v${f.app_version||"?"}</div>
    </div>`).join("");
}

window.filterFeedback = function() {
  const q      = document.getElementById("feedbackSearch").value.toLowerCase();
  const cat    = document.getElementById("feedbackCatFilter").value;
  const status = document.getElementById("feedbackStatusFilter").value;
  const list   = allFeedback.filter(f => {
    if (q && !(f.message||"").toLowerCase().includes(q) && !(f.display_name||"").toLowerCase().includes(q)) return false;
    if (cat !== "all" && f.category !== cat) return false;
    if (status === "unread")   return !f.is_read;
    if (status === "read")     return f.is_read && !f.is_resolved;
    if (status === "resolved") return f.is_resolved;
    return true;
  });
  renderFeedback(list);
};

window.markRead = async function(id) {
  await updateDoc(doc(db,"feedbacks",id), { is_read: true });
  const f = allFeedback.find(x=>x.id===id); if(f) f.is_read=true;
  renderFeedback(allFeedback); showToast("Okundu olarak işaretlendi.");
};
window.markResolved = async function(id) {
  await updateDoc(doc(db,"feedbacks",id), { is_read:true, is_resolved:true });
  const f = allFeedback.find(x=>x.id===id); if(f){f.is_read=true;f.is_resolved=true;}
  renderFeedback(allFeedback); showToast("✓ Çözüldü olarak işaretlendi.");
};
window.deleteFeedback = async function(id) {
  if (!confirm("Bu geri bildirimi silmek istediğinizden emin misiniz?")) return;
  await deleteDoc(doc(db,"feedbacks",id));
  allFeedback = allFeedback.filter(x=>x.id!==id);
  renderFeedback(allFeedback); showToast("Silindi.", "error");
};

// ─────────────────────────────────────────
// LEADERBOARD
// ─────────────────────────────────────────
window.loadLeaderboard = async function() {
  const game = document.getElementById("gameSelect").value;
  const body = document.getElementById("leaderboardBody");
  body.innerHTML = `<tr><td colspan="5" class="loading-row">Yükleniyor…</td></tr>`;
  const higherBetter = game !== "minesweeper";
  const snap = await getDocs(query(
    collection(db,"leaderboards",game,"scores"),
    orderBy("score", higherBetter?"desc":"asc"), limit(50)
  ));
  const rows = snap.docs.map((d,i) => ({ rank:i+1, id:d.id, ...d.data() }));
  body.innerHTML = rows.length
    ? rows.map(r => `
      <tr>
        <td><span class="rank ${r.rank<=3?'r'+r.rank:''}">${r.rank<=3?['🥇','🥈','🥉'][r.rank-1]:r.rank}</span></td>
        <td>${r.display_name||"Anonim"}</td>
        <td><strong>${r.score?.toLocaleString("tr-TR")}</strong></td>
        <td>${fmtDate(r.updated_at)}</td>
        <td><button class="action-btn red" onclick="deleteScore('${game}','${r.id}')">Sil</button></td>
      </tr>`).join("")
    : `<tr><td colspan="5" class="loading-row">Skor bulunamadı.</td></tr>`;
};

window.deleteScore = async function(game, uid) {
  if (!confirm("Bu skoru silmek istediğinizden emin misiniz?")) return;
  await deleteDoc(doc(db,"leaderboards",game,"scores",uid));
  await window.loadLeaderboard(); showToast("Skor silindi.", "error");
};

// ── Page load ──
document.addEventListener("DOMContentLoaded", () => {
  // render initial tables when data is loaded
  // Stars canvas in login
  const canvas = document.getElementById("loginStars");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  canvas.width = window.innerWidth; canvas.height = window.innerHeight;
  const stars = Array.from({length:80}, () => ({
    x: Math.random()*canvas.width, y: Math.random()*canvas.height,
    r: Math.random()*1.5+0.3, o: Math.random()*0.5+0.1,
    s: Math.random()*0.4+0.2, p: Math.random()*Math.PI*2
  }));
  let t=0;
  (function animate(){
    ctx.clearRect(0,0,canvas.width,canvas.height);
    stars.forEach(s=>{
      const tw=(Math.sin(t*s.s*2*Math.PI+s.p)+1)/2;
      ctx.globalAlpha=s.o*(0.15+0.85*tw);
      ctx.fillStyle="#fff"; ctx.beginPath();
      ctx.arc(s.x,s.y,s.r*(0.6+0.4*tw),0,Math.PI*2); ctx.fill();
    });
    t+=0.016; requestAnimationFrame(animate);
  })();
});

// After data loaded, render tables
async function loadUsers() {
  if (allUsers.length === 0) {
    const snap = await getDocs(query(collection(db,"users"), orderBy("created_at","desc")));
    allUsers = snap.docs.map(d => ({ id:d.id, ...d.data() }));
  }
  renderUsers(allUsers);
  renderPremium(allUsers);
}
