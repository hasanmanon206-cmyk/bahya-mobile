async function loadHtml(path){
  const r = await fetch(path);
  return await r.text();
}

function setClock(){
  const el = document.getElementById("mgrLiveClock");
  if(!el) return;
  const t = new Date();
  const hh = String(t.getHours()).padStart(2,'0');
  const mm = String(t.getMinutes()).padStart(2,'0');
  const ss = String(t.getSeconds()).padStart(2,'0');
  el.textContent = `🕒 ${hh}:${mm}:${ss}`;
}

function bindManager(){
  // Tabs
  const tabs = document.querySelectorAll(".tab");
  const pages = document.querySelectorAll(".tabPage");
  tabs.forEach(b=>{
    b.addEventListener("click", ()=>{
      tabs.forEach(x=>x.classList.remove("active"));
      b.classList.add("active");
      const id = b.dataset.tab;
      pages.forEach(p=>{
        p.classList.toggle("hidden", p.dataset.page !== id);
      });
    });
  });

  // Clock live
  setClock();
  setInterval(setClock, 1000);
}

export async function showManager(){
  const app = document.getElementById("app");
  app.innerHTML = await loadHtml("src/screens/manager.html");
  bindManager();
}

export async function route(){
  const h = location.hash.replace("#","") || "home";
  if(h === "manager") return showManager();

  // fallback: إذا عندك شاشة home قديمة
  // هنا نخليها بسيطة
  const app = document.getElementById("app");
  app.innerHTML = `
    <div class="screen">
      <div class="topbar glass">
        <div class="brand">
          <div class="title">قهوة البلة</div>
          <div class="subtitle">اختر شاشة</div>
        </div>
        <div class="topmeta">
          <a class="btn primary" href="#manager">لوحة المدير</a>
        </div>
      </div>
      <div class="glass" style="padding:14px;border-radius:16px">
        إذا بدك أربط باقي الشاشات (كاشير/جارسون/مَكنة/زبون) على نفس الراوتر خبرني.
      </div>
    </div>
  `;
}

window.addEventListener("hashchange", route);
window.addEventListener("load", route);
