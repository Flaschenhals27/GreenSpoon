// supabase/functions/generate-recipes/index.ts
//
// Edge Function: erzeugt KI-Rezeptvorschläge basierend auf den
// bald ablaufenden Vorrats-Items des aktuellen Users.
//
// Pipeline:
//   1. Auth: User-JWT prüfen, user_id ermitteln
//   2. Items aus pantry_items lesen (RLS sorgt für Isolation)
//   3. Prompt für Gemini bauen
//   4. Gemini aufrufen, JSON-Antwort parsen
//   5. Strukturiertes Ergebnis zurück an Client

import { createClient } from "jsr:@supabase/supabase-js@2";

// CORS-Header für Web-Clients (falls du die App später auch im Browser
// laufen lassen willst). Auf Android egal, schadet aber nicht.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface PantryItem {
  name: string;
  category: string;
  quantity: string | null;
  expires_at: string | null;
}

interface Recipe {
  title: string;
  meal: "Frühstück" | "Mittag" | "Abend";
  time_min: number;
  difficulty: "Einfach" | "Mittel" | "Anspruchsvoll";
  servings: number;
  tags: string[];
  uses: string[];
  missing: string[];
  blurb: string;
  steps: string[];
}

Deno.serve(async (req: Request) => {
  // Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    // ─── 1. Auth ────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return jsonError("Missing Authorization header", 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // Client mit User-JWT — RLS greift automatisch
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userResp, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userResp?.user) {
      return jsonError("Invalid token", 401);
    }

    // ─── 2. Vorrats-Items lesen ─────────────────────────────────
    const { data: items, error: itemsErr } = await supabase
      .from("pantry_items")
      .select("name, category, quantity, expires_at")
      .order("expires_at", { ascending: true, nullsFirst: false });

    if (itemsErr) return jsonError(`DB error: ${itemsErr.message}`, 500);
    if (!items || items.length === 0) {
      return jsonOk({ recipes: [], message: "Vorrat ist leer." });
    }

    // ─── 3. Prompt bauen ────────────────────────────────────────
    const today = new Date();
    const expiringSoon: PantryItem[] = [];
    const otherItems: PantryItem[] = [];

    for (const item of items as PantryItem[]) {
      if (!item.expires_at) {
        otherItems.push(item);
        continue;
      }
      const exp = new Date(item.expires_at);
      const daysLeft = Math.floor(
        (exp.getTime() - today.getTime()) / (1000 * 60 * 60 * 24),
      );
      if (daysLeft <= 5) expiringSoon.push(item);
      else otherItems.push(item);
    }

    const formatItem = (i: PantryItem) => {
      const qty = i.quantity ? ` (${i.quantity})` : "";
      const exp = i.expires_at ? `, MHD ${i.expires_at}` : "";
      return `- ${i.name}${qty} [${i.category}${exp}]`;
    };

    const prompt = `Du bist ein deutscher Koch und hilfst, Lebensmittel vor dem Ablauf zu retten.

DRINGEND ZU VERWERTEN (läuft in 0-5 Tagen ab):
${expiringSoon.map(formatItem).join("\n") || "(keine)"}

WEITERER VORRAT:
${otherItems.slice(0, 20).map(formatItem).join("\n") || "(leer)"}

Schlage genau 3 Rezepte vor. Jeweils 1× Frühstück, 1× Mittag, 1× Abend.
Bevorzuge Rezepte, die möglichst viele DRINGEND ZU VERWERTENDE Zutaten nutzen.

Antworte AUSSCHLIESSLICH mit gültigem JSON in genau diesem Format,
ohne Markdown, ohne Code-Fence, ohne Kommentare:

{
  "recipes": [
    {
      "title": "Rezeptname",
      "meal": "Frühstück" | "Mittag" | "Abend",
      "time_min": 15,
      "difficulty": "Einfach" | "Mittel" | "Anspruchsvoll",
      "servings": 2,
      "tags": ["Vegetarisch", "Schnell"],
      "uses": ["Zutat aus dem Vorrat", "..."],
      "missing": ["Zutat, die fehlt", "..."],
      "blurb": "Ein-Satz-Beschreibung, einladend, max. 80 Zeichen.",
      "steps": ["Schritt 1.", "Schritt 2.", "..."]
    }
  ]
}

Sprache: Deutsch, Du-Form. Realistisch, einfach umsetzbar.`;

    // ─── 4. Gemini aufrufen ─────────────────────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) return jsonError("GEMINI_API_KEY missing", 500);

    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`;

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          responseMimeType: "application/json",
        },
      }),
    });

    if (!geminiRes.ok) {
      const errBody = await geminiRes.text();
      return jsonError(
        `Gemini error ${geminiRes.status}: ${errBody.slice(0, 300)}`,
        502,
      );
    }

    const geminiJson = await geminiRes.json();
    const text =
      geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // ─── 5. JSON aus Gemini-Antwort parsen ──────────────────────
    let parsed: { recipes: Recipe[] };
    try {
      parsed = JSON.parse(text);
    } catch (_e) {
      return jsonError(
        `Konnte Gemini-Antwort nicht parsen. Roh: ${text.slice(0, 300)}`,
        502,
      );
    }

    if (!parsed?.recipes || !Array.isArray(parsed.recipes)) {
      return jsonError("Antwortformat ungültig (keine recipes-Liste)", 502);
    }

    return jsonOk({
      recipes: parsed.recipes,
      generated_at: new Date().toISOString(),
      pantry_size: items.length,
    });
  } catch (e) {
    return jsonError(`Unhandled: ${(e as Error).message}`, 500);
  }
});

function jsonOk(body: unknown) {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status = 400) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}