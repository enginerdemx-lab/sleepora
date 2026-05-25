// Sleepora animated site — interactivity
(() => {
  /* ===== Mobile nav toggle ===== */
  const navToggle = document.getElementById('navToggle');
  const mobileNav = document.getElementById('mobileNav');
  if (navToggle && mobileNav) {
    const closeNav = () => {
      navToggle.classList.remove('open');
      mobileNav.classList.remove('open');
      navToggle.setAttribute('aria-expanded', 'false');
    };
    navToggle.addEventListener('click', () => {
      const isOpen = navToggle.classList.toggle('open');
      mobileNav.classList.toggle('open', isOpen);
      navToggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
    });
    mobileNav.querySelectorAll('a').forEach((a) => a.addEventListener('click', closeNav));
  }

  /* ===== Custom cursor ===== */
  const dot = document.querySelector('.cursor-dot');
  const ring = document.querySelector('.cursor-ring');
  let mx = window.innerWidth / 2, my = window.innerHeight / 2;
  let rx = mx, ry = my;
  document.addEventListener('mousemove', (e) => {
    mx = e.clientX; my = e.clientY;
    if (dot) dot.style.transform = `translate3d(${mx - 4}px, ${my - 4}px, 0)`;
  });
  function loopCursor() {
    rx += (mx - rx) * 0.15;
    ry += (my - ry) * 0.15;
    if (ring) ring.style.transform = `translate3d(${rx - 19}px, ${ry - 19}px, 0)`;
    requestAnimationFrame(loopCursor);
  }
  loopCursor();
  document.querySelectorAll('a, button, .sound-pad, .step-card, .game-card, .game-row, .gr-play, .bento-card, .metric-card, .faq-q, .tt-card, .mixer-tile').forEach((el) => {
    el.addEventListener('mouseenter', () => ring && ring.classList.add('is-hover'));
    el.addEventListener('mouseleave', () => ring && ring.classList.remove('is-hover'));
  });

  /* ===== Starfield ===== */
  const canvas = document.getElementById('starfield');
  if (canvas) {
    const ctx = canvas.getContext('2d');
    let stars = [];
    function resize() {
      canvas.width = window.innerWidth * devicePixelRatio;
      canvas.height = window.innerHeight * devicePixelRatio;
      canvas.style.width = window.innerWidth + 'px';
      canvas.style.height = window.innerHeight + 'px';
      ctx.scale(devicePixelRatio, devicePixelRatio);
      stars = [];
      const count = Math.floor((window.innerWidth * window.innerHeight) / 9000);
      for (let i = 0; i < count; i++) {
        stars.push({
          x: Math.random() * window.innerWidth,
          y: Math.random() * window.innerHeight,
          r: Math.random() * 1.4 + 0.2,
          a: Math.random() * 0.7 + 0.2,
          tw: Math.random() * 2 + 1,
          phase: Math.random() * Math.PI * 2,
        });
      }
    }
    resize();
    window.addEventListener('resize', resize);
    function drawStars(t) {
      ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
      for (const s of stars) {
        const flicker = 0.55 + 0.45 * Math.sin(t / 700 * s.tw + s.phase);
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(235, 222, 255, ${s.a * flicker})`;
        ctx.fill();
        if (s.r > 1.1) {
          ctx.beginPath();
          ctx.arc(s.x, s.y, s.r * 3, 0, Math.PI * 2);
          ctx.fillStyle = `rgba(157, 104, 255, ${0.04 * flicker})`;
          ctx.fill();
        }
      }
      requestAnimationFrame(drawStars);
    }
    requestAnimationFrame(drawStars);
  }

  /* ===== Hero word reveal ===== */
  const h1 = document.querySelector('.hero-copy h1');
  if (h1 && !h1.dataset.split) {
    const html = h1.innerHTML;
    h1.dataset.split = '1';
    // Split text but preserve <span class="gradient">…</span>
    const wrap = document.createElement('span');
    wrap.innerHTML = html;
    const out = [];
    let delay = 0;
    function processNode(node, gradient) {
      if (node.nodeType === Node.TEXT_NODE) {
        const words = node.textContent.split(/(\s+)/);
        for (const w of words) {
          if (w.trim() === '') {
            out.push(w);
          } else {
            const cls = gradient ? 'word gradient' : 'word';
            out.push(`<span class="${cls}" style="animation-delay:${delay}s">${w}</span>`);
            delay += 0.06;
          }
        }
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        const isGrad = node.classList && node.classList.contains('gradient');
        for (const child of node.childNodes) processNode(child, isGrad);
      }
    }
    for (const child of wrap.childNodes) processNode(child, false);
    h1.innerHTML = out.join('');
  }

  /* ===== Phone slideshow (hero) ===== */
  const slides = [...document.querySelectorAll('.hero-visual .phone-slide')];
  const dots = [...document.querySelectorAll('.phone-dots .dot')];
  let active = 0, autoT;
  function go(i) {
    active = i;
    slides.forEach((s, k) => s.classList.toggle('active', k === i));
    dots.forEach((d, k) => d.classList.toggle('active', k === i));
  }
  function startAuto() {
    clearInterval(autoT);
    autoT = setInterval(() => go((active + 1) % slides.length), 4200);
  }
  dots.forEach((d, i) => d.addEventListener('click', () => { go(i); startAuto(); }));
  if (slides.length) { go(0); startAuto(); }

  /* ===== Reveal observer ===== */
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        e.target.classList.add('is-visible');
        io.unobserve(e.target);
      }
    });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach((el) => io.observe(el));

  /* ===== Count-up metrics ===== */
  const counters = document.querySelectorAll('[data-count]');
  const counterIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      const el = e.target;
      const target = parseFloat(el.dataset.count);
      const suffix = el.dataset.suffix || '';
      const dur = 1500;
      const t0 = performance.now();
      function tick(t) {
        const p = Math.min(1, (t - t0) / dur);
        const eased = 1 - Math.pow(1 - p, 3);
        const v = target * eased;
        el.textContent = (Number.isInteger(target) ? Math.round(v) : v.toFixed(1)) + suffix;
        if (p < 1) requestAnimationFrame(tick);
      }
      requestAnimationFrame(tick);
      counterIO.unobserve(el);
    });
  }, { threshold: 0.5 });
  counters.forEach((c) => counterIO.observe(c));

  /* ===== Showcase scroll-pinned phone ===== */
  const stepCards = [...document.querySelectorAll('.step-card')];
  const showcaseSlides = [...document.querySelectorAll('.showcase-phone .phone-slide')];
  function setShowcase(i) {
    stepCards.forEach((c, k) => c.classList.toggle('active', k === i));
    showcaseSlides.forEach((s, k) => s.classList.toggle('active', k === i));
  }
  if (stepCards.length) {
    setShowcase(0);
    stepCards.forEach((card, i) => card.addEventListener('click', () => setShowcase(i)));
    // Auto-rotate when section visible
    let scIdx = 0, scTimer;
    const scIO = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          clearInterval(scTimer);
          scTimer = setInterval(() => {
            scIdx = (scIdx + 1) % stepCards.length;
            setShowcase(scIdx);
          }, 3800);
        } else {
          clearInterval(scTimer);
        }
      });
    }, { threshold: 0.3 });
    const sc = document.querySelector('.showcase');
    if (sc) scIO.observe(sc);
    stepCards.forEach((card, i) => card.addEventListener('click', () => { scIdx = i; }));
  }

  /* ===== Mixer demo ===== */
  const pads = [...document.querySelectorAll('.sound-pad')];
  const summaryCount = document.querySelector('.mixer-summary .count strong');
  const liveBars = document.querySelectorAll('.mixer-summary .live-bars span');
  function syncMixer() {
    const playing = pads.filter((p) => p.classList.contains('playing')).length;
    if (summaryCount) summaryCount.textContent = String(playing);
    liveBars.forEach((b) => b.style.opacity = playing ? '1' : '0.18');
  }
  pads.forEach((pad) => pad.addEventListener('click', () => {
    pad.classList.toggle('playing');
    syncMixer();
  }));
  // Start with 3 active for delight
  if (pads.length) {
    [0, 3, 7].forEach((i) => pads[i] && pads[i].classList.add('playing'));
    syncMixer();
  }

  /* ===== FAQ ===== */
  document.querySelectorAll('.faq-item').forEach((item) => {
    const q = item.querySelector('.faq-q');
    const a = item.querySelector('.faq-a');
    q.addEventListener('click', () => {
      const open = item.classList.toggle('open');
      a.style.maxHeight = open ? a.scrollHeight + 'px' : '0';
    });
  });

  /* ===== Magnetic buttons ===== */
  document.querySelectorAll('.store-button, .nav-cta, .text-button').forEach((btn) => {
    btn.addEventListener('mousemove', (e) => {
      const r = btn.getBoundingClientRect();
      const x = e.clientX - r.left - r.width / 2;
      const y = e.clientY - r.top - r.height / 2;
      btn.style.transform = `translate(${x * 0.12}px, ${y * 0.18}px)`;
    });
    btn.addEventListener('mouseleave', () => { btn.style.transform = ''; });
  });

  /* ===== Download card spotlight ===== */
  const dlCard = document.querySelector('.download-card');
  if (dlCard) {
    dlCard.addEventListener('mousemove', (e) => {
      const r = dlCard.getBoundingClientRect();
      dlCard.style.setProperty('--mx', `${e.clientX - r.left}px`);
      dlCard.style.setProperty('--my', `${e.clientY - r.top}px`);
    });
  }

  /* ===== Hero parallax (mouse) — desktop only ===== */
  const phone = document.querySelector('.hero-visual .phone');
  const moon = document.querySelector('.bg-moon');
  const isCoarse = window.matchMedia('(pointer: coarse)').matches || window.innerWidth < 900;
  if (!isCoarse) document.addEventListener('mousemove', (e) => {
    const px = (e.clientX / window.innerWidth - 0.5);
    const py = (e.clientY / window.innerHeight - 0.5);
    if (phone) phone.style.setProperty('--tilt', `rotateY(${px * 6}deg) rotateX(${-py * 4}deg)`);
    if (moon) moon.style.setProperty('--shift', `translate(${px * 18}px, ${py * 14}px)`);
  });

  /* Lock to animated night theme */
  document.body.dataset.theme = 'night';
  document.body.dataset.anim = 'high';

  /* ===== Interactive Timer Widget ===== */
  const tw = document.getElementById('timerWidget');
  if (tw) {
    const slider = document.getElementById('twSlider');
    const fill = document.getElementById('twFill');
    const thumb = document.getElementById('twThumb');
    const num = document.getElementById('twNum');
    const presets = document.getElementById('twPresets');
    const MIN = 0, MAX = 90;
    let val = 45;

    function render(v, withBump) {
      val = Math.max(MIN, Math.min(MAX, Math.round(v)));
      const pct = ((val - MIN) / (MAX - MIN)) * 100;
      fill.style.setProperty('width', pct + '%', 'important');
      thumb.style.setProperty('left', pct + '%', 'important');
      const display = val >= 60 ? (val / 60 % 1 === 0 ? (val/60) + ' sa' : (val/60).toFixed(1) + 's') : val;
      // For preset display, simpler: show minutes if <60 else 1 sa, 1.5s, 2s
      let label = val;
      let unit = 'dk';
      if (val >= 60) { label = (val/60 % 1 === 0) ? (val/60) : (val/60).toFixed(1).replace('.0',''); unit = val === 60 ? 'sa' : 's'; }
      num.textContent = label;
      num.nextElementSibling.textContent = unit;
      if (withBump) {
        num.classList.remove('bump'); void num.offsetWidth; num.classList.add('bump');
      }
      // sync presets
      [...presets.querySelectorAll('button')].forEach(b => {
        b.classList.toggle('on', parseInt(b.dataset.min, 10) === val);
      });
    }

    function fromEvent(e) {
      const r = slider.getBoundingClientRect();
      const cx = (e.touches && e.touches[0]) ? e.touches[0].clientX
               : (e.changedTouches && e.changedTouches[0]) ? e.changedTouches[0].clientX
               : e.clientX;
      const x = cx - r.left;
      const pct = Math.max(0, Math.min(1, x / r.width));
      const v = Math.round((MIN + pct * (MAX - MIN)) / 5) * 5;
      render(v);
    }

    let dragging = false;
    slider.addEventListener('pointerdown', (e) => {
      dragging = true;
      try { slider.setPointerCapture(e.pointerId); } catch (_) {}
      fromEvent(e);
      e.preventDefault();
    });
    slider.addEventListener('pointermove', (e) => {
      if (dragging) { fromEvent(e); e.preventDefault(); }
    });
    const endDrag = (e) => {
      if (!dragging) return;
      dragging = false;
      try { slider.releasePointerCapture(e.pointerId); } catch (_) {}
    };
    slider.addEventListener('pointerup', endDrag);
    slider.addEventListener('pointercancel', endDrag);
    slider.addEventListener('lostpointercapture', () => { dragging = false; });
    // Fallback for browsers without pointer events
    slider.addEventListener('touchmove', (e) => { if (dragging) { fromEvent(e); } }, { passive: true });

    presets.addEventListener('click', (e) => {
      const b = e.target.closest('button[data-min]');
      if (!b) return;
      let v = parseInt(b.dataset.min, 10);
      // Cap at MAX 90 visually for slider; over-cap presets still render number
      render(Math.min(v, MAX), true);
    });

    render(45);
  }
})();
