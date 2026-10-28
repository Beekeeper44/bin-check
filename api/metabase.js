// Proxy to Metabase. ?q=bins | cards, optional &bins=701 or 701-750
export default async function handler(req, res) {
  const METABASE_HOST = process.env.METABASE_HOST || 'https://arena-club.metabaseapp.com';
  const { METABASE_API_KEY } = process.env;
  const ITEMS_QUESTION_ID = process.env.ITEMS_QUESTION_ID || '46004';
  const BINS_QUESTION_ID = process.env.BINS_QUESTION_ID || '46003';
  if (!METABASE_HOST || !METABASE_API_KEY) {
    return res.status(500).json({ error: 'Missing METABASE_HOST or METABASE_API_KEY in Vercel env.' });
  }
  const q = req.query.q;
  const id = q === 'bins' ? BINS_QUESTION_ID : q === 'items' ? ITEMS_QUESTION_ID : null;
  if (!id) {
    return res.status(400).json({ error: `Question "${q}" is not configured. Use q=bins or q=items.` });
  }

  const params = [];
  if (req.query.bins) {
    params.push({ type: 'category', target: ['variable', ['template-tag', 'bins']], value: String(req.query.bins) });
  }

  const host = METABASE_HOST.replace(/\/+$/, '');
  try {
    const r = await fetch(`${host}/api/card/${id}/query/json`, {
      method: 'POST',
      headers: { 'x-api-key': METABASE_API_KEY, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'parameters=' + encodeURIComponent(JSON.stringify(params)),
    });
    const text = await r.text();
    if (!r.ok) return res.status(r.status).json({ error: `Metabase ${r.status}: ${text.slice(0, 300)}` });
    let data;
    try { data = JSON.parse(text); } catch { return res.status(502).json({ error: 'Metabase returned non-JSON.' }); }
    if (!Array.isArray(data)) return res.status(502).json({ error: data.error || 'Unexpected Metabase response.' });
    res.setHeader('Cache-Control', 'no-store');
    return res.status(200).json({ rows: data });
  } catch (e) {
    return res.status(502).json({ error: 'Could not reach Metabase: ' + e.message });
  }
}
