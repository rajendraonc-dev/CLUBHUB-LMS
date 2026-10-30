// public/js/ai-chat.js — Frontend AI Tutor (Fetch API, tanpa refresh halaman)
// HTML minimal:
//   <div id="chat-box" aria-live="polite"></div>
//   <form id="chat-form"><textarea id="chat-input" maxlength="1500"></textarea>
//   <button id="chat-send" type="submit">Kirim</button></form>
(() => {
  const ENDPOINT = '/api/ai-tutor.php';   // ganti ke '/api/ai-tutor' jika memakai Node.js
  const box   = document.getElementById('chat-box');
  const form  = document.getElementById('chat-form');
  const input = document.getElementById('chat-input');
  const send  = document.getElementById('chat-send');
  const moduleId = Number(document.body.dataset.moduleId) || null;

  // Render aman (anti-XSS): hanya textContent; blok ``` diubah menjadi <pre><code>
  function renderContent(container, text) {
    text.split(/```(?:\w+)?\n?/).forEach((part, i) => {
      if (!part) return;
      if (i % 2 === 1) {
        const pre = document.createElement('pre');
        const code = document.createElement('code');
        code.textContent = part.trim();
        pre.appendChild(code);
        container.appendChild(pre);
      } else {
        const p = document.createElement('p');
        p.textContent = part.trim();
        container.appendChild(p);
      }
    });
  }

  function addMessage(role, text) {
    const el = document.createElement('div');
    el.className = `msg msg-${role}`;
    renderContent(el, text);
    box.appendChild(el);
    box.scrollTop = box.scrollHeight;
    return el;
  }

  function setLoading(on) {
    send.disabled = on;
    input.disabled = on;
    send.textContent = on ? 'Mengirim…' : 'Kirim';
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const prompt = input.value.trim();
    if (!prompt) return;

    addMessage('user', prompt);
    input.value = '';
    setLoading(true);
    const typing = addMessage('ai', 'AI Tutor sedang mengetik…');

    try {
      const res = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ prompt, module_id: moduleId }),
      });
      const data = await res.json();
      typing.remove();
      addMessage('ai', data.ok ? data.reply : (data.error || 'Terjadi kesalahan.'));
    } catch (err) {
      typing.remove();
      addMessage('ai', 'Koneksi bermasalah. Periksa jaringan Anda lalu coba lagi.');
    } finally {
      setLoading(false);
      input.focus();
    }
  });

  // Enter = kirim, Shift+Enter = baris baru
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); form.requestSubmit(); }
  });
})();
