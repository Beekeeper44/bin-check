// Proxy to Metabase. ?q=bins | items, optional &bins=701 or 701-750
const HEADERS = key => ({ 'x-api-key': key });
const metaCache = {};

// Metabase needs each parameter's id, so read it from the saved question.
async function getBinsParam(host, key, id) {
  if (metaCache[id] !== undefined) return metaCache[id];
  const r = await fetch(`${host}/api/card/${id}`, { headers: HEADERS(key) });
  if (!r.ok) throw new Error(`Metabase ${r.status} reading question ${id}`);
  const card = await r.json();
  const dq = card.dataset_query || {};
  const tags = dq.native?.['template-tags'] || dq.stages?.[0]?.['template-tags'] || {};
  const tag = tags.bins || Object.values(tags).find(t => t.name === 'bins');
  const p = (card.parameters || []).find(p =>
    p.slug === 'bins' || (Array.isArray(p.target) && JSON.stringify(p.target).includes('"bins"')));
  metaCache[id] = tag || p ? {
    id: p?.id || tag?.id,
    type: p?.type || (tag?.type === 'number' ? 'number/=' : 'category'),
    target: p?.target || ['variable', ['template-tag', 'bins']],
  } : null;
  return metaCache[id];
}

function inRange(binValue, spec) {
  const n = Number(binValue);
  return String(spec).replace(/\s/g, '').split(',').filter(Boolean).some(part => {
    const [a, b] = part.split('-').map(Number);
    const lo = Math.min(a, isNaN(b) ? a : b), hi = Math.max(a, isNaN(b) ? a : b);
    return n >= lo && n <= hi;
  });
}

export default async function handler(req, res) {
  const host = (process.env.METABASE_HOST || 'https://arena-club.metabaseapp.com').replace(/\/+$/, '');
  const key = process.env.METABASE_API_KEY;
  const BINS_QUESTION_ID = process.env.BINS_QUESTION_ID || '46003';
  const ITEMS_QUESTION_ID = process.env.ITEMS_QUESTION_ID || '46004';
  if (!key) return res.status(500).json({ error: 'Missing METABASE_API_KEY in Vercel env.' });

  const q = req.query.q;
  const id = q === 'bins' ? BINS_QUESTION_ID : q === 'items' ? ITEMS_QUESTION_ID : null;
  if (!id) return res.status(400).json({ error: `Unknown question "${q}". Use q=bins or q=items.` });

  const binsSpec = req.query.bins ? String(req.query.bins) : '';
  try {
    const params = [];
    let filterHere = false;
    if (binsSpec) {
      const bp = await getBinsParam(host, key, id);
      if (bp && bp.id) params.push({ id: bp.id, type: bp.type, target: bp.target, value: bp.type === 'number/=' ? [Number(binsSpec)] : binsSpec });
      else filterHere = true; // question has no bins filter: load all, filter below
    }

    const r = await fetch(`${host}/api/card/${id}/query/json`, {
      method: 'POST',
      headers: { ...HEADERS(key), 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'parameters=' + encodeURIComponent(JSON.stringify(params)),
    });
    const text = await r.text();
    if (!r.ok) return res.status(r.status).json({ error: `Metabase ${r.status}: ${text.slice(0, 300)}` });
    let data;
    try { data = JSON.parse(text); } catch { return res.status(502).json({ error: 'Metabase returned non-JSON.' }); }
    if (!Array.isArray(data)) return res.status(502).json({ error: data.error || 'Unexpected Metabase response.' });

    if (filterHere) {
      const binKey = data.length ? Object.keys(data[0]).find(k => k.replace(/[^a-z]/gi, '').toLowerCase() === 'binnumber') : null;
      if (binKey) data = data.filter(row => inRange(row[binKey], binsSpec));
    }
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json({ rows: data });
  } catch (e) {
    return res.status(502).json({ error: 'Could not reach Metabase: ' + e.message });
  }
}
