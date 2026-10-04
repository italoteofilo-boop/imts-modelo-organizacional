// Regra do terço no navegador (Editorial Legal.OS): a última linha de cada parágrafo tem pelo menos 1/3 da anterior.
// Ordem do ajuste: espaçamento entre letras até 0,2 pt; espaço entre palavras de -0,5 a +1,0 pt (com ou sem o ajuste entre
// letras); até quatro palavras puxadas para a última linha, com a penúltima mantendo 85% da linha cheia.
// Mede com o texto alinhado à esquerda (a justificação não muda as quebras de linha no Chromium). Devolve os alertas.
(() => {
  const linhas = (el) => {
    const old = el.style.textAlign; el.style.textAlign = 'left';
    const r = document.createRange(); r.selectNodeContents(el);
    const rects = [...r.getClientRects()].filter((q) => q.width > 0.5);
    el.style.textAlign = old;
    const ls = [];
    for (const q of rects) {
      const l = ls.find((x) => Math.abs(x.top - q.top) < 3);
      if (l) { l.left = Math.min(l.left, q.left); l.right = Math.max(l.right, q.right); }
      else ls.push({ top: q.top, left: q.left, right: q.right });
    }
    ls.sort((a, b) => a.top - b.top);
    return ls.map((l) => l.right - l.left);
  };
  const ok = (el) => { const w = linhas(el); return w.length < 2 || w[w.length - 1] >= w[w.length - 2] / 3; };
  const largura = (el) => { const cs = getComputedStyle(el); return el.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight); };
  const alertas = []; let ajustados = 0;
  const alvo = document.querySelectorAll('p, li, .nota, table.t td');
  const LS = [0.05, -0.05, 0.1, -0.1, 0.15, -0.15, 0.2, -0.2];
  const WS = [0.25, -0.25, 0.5, -0.5, 0.75, 1.0];
  for (const el of alvo) {
    if (ok(el)) continue;
    let feito = false;
    for (const ls of LS) { el.style.letterSpacing = ls + 'pt'; if (ok(el)) { feito = true; break; } }
    if (!feito) { el.style.letterSpacing = '';
      for (const ws of WS) { el.style.wordSpacing = ws + 'pt'; if (ok(el)) { feito = true; break; } }
    }
    if (!feito) {
      outer: for (const ls of [0.1, -0.1, 0.2, -0.2]) for (const ws of WS) {
        el.style.letterSpacing = ls + 'pt'; el.style.wordSpacing = ws + 'pt'; if (ok(el)) { feito = true; break outer; }
      }
    }
    if (!feito) { el.style.letterSpacing = ''; el.style.wordSpacing = '';
      // puxar até quatro palavras: prende o fim do texto numa unidade sem quebra (span nowrap), sem espaço nem quebra manual
      const t = el.lastChild;
      if (t && t.nodeType === 3 && t.textContent.trim()) {
        const txt = t.textContent;
        const re = /\S+/g; const pos = []; let m; while ((m = re.exec(txt))) pos.push(m.index);
        // palavras que estão hoje na última linha (medidas pela posição de cada palavra)
        const old = el.style.textAlign; el.style.textAlign = 'left';
        const topo = (i) => { const r = document.createRange(); r.setStart(t, pos[i]); r.setEnd(t, pos[i] + 1); return r.getClientRects()[0]?.top ?? 0; };
        const ultTop = topo(pos.length - 1); let naUlt = 0;
        for (let i = pos.length - 1; i >= 0 && Math.abs(topo(i) - ultTop) < 3; i--) naUlt++;
        el.style.textAlign = old;
        const nLin = linhas(el).length;
        for (let k = 1; k <= 4 && !feito; k++) {
          const n = naUlt + k; if (n >= pos.length) break;
          const idx = pos[pos.length - n];
          const span = document.createElement('span'); span.className = 'junto'; span.style.whiteSpace = 'nowrap'; span.textContent = txt.slice(idx);
          const antes = document.createTextNode(txt.slice(0, idx));
          el.replaceChild(antes, t); el.appendChild(span);
          const w = linhas(el);
          if (w.length === nLin && w[w.length - 1] >= w[w.length - 2] / 3 && w[w.length - 2] >= 0.85 * largura(el)) feito = true;
          else { el.removeChild(span); el.replaceChild(t, antes); }
        }
      }
    }
    if (feito) ajustados++;
    else alertas.push({ texto: (el.innerText || '').slice(0, 90), motivo: 'última linha com menos de um terço da anterior' });
  }
  window.__ajuste = { ajustados, alertas };
  return window.__ajuste;
})();
