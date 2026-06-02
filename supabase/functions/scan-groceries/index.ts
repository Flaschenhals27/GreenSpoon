// supabase/functions/scan-groceries/index.ts
//
// Edge Function: erkennt mehrere Lebensmittel auf EINEM Foto (loses Obst/
// Gemüse/Brot ohne Barcode) und gleicht sie mit dem vorhandenen Vorrat ab.
//
// Pipeline:
//   1. Auth: User-JWT prüfen
//   2. Body lesen: { image: <base64>, mimeType? }
//   3. Aktuellen Vorrat des Users laden (für den Neu/Schon-da-Abgleich)
//   4. Gemini (Vision) aufrufen mit Bild + Vorrats-Snapshot
//   5. Strukturierte Liste zurückgeben

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Muss mit kPantryCategories (lib/features/pantry/domain/pantry_categories.dart)
// übereinstimmen.
const CATEGORIES = [
  "Milchprodukte",
  "Obst",
  "Gemüse",
  "Fleisch & Fisch",
  "Hülsenfrüchte & Tofu",
  "Pasta & Reis",
  "Brot & Backwaren",
  "Backzutaten",
  "Müsli & Cerealien",
  "Eier",
  "Süßes & Snacks",
  "Gewürze & Saucen",
  "Öle & Fette",
  "Aufstriche",
  "Konserven",
  "Tiefkühl",
  "Getränke",
  "Sonstiges",
];

interface PantryRow {
  name: string;
  category: string;
}

Deno.serve(async (req: Request) => {
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
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userResp, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userResp?.user) {
      return jsonError("Invalid token", 401);
    }

    // ─── 2. Body lesen ──────────────────────────────────────────
    let imageB64: string | null = null;
    let mimeType = "image/jpeg";
    try {
      const body = await req.json();
      if (body && typeof body.image === "string") imageB64 = body.image;
      if (body && typeof body.mimeType === "string") mimeType = body.mimeType;
    } catch (_e) {
      return jsonError("Body muss JSON mit { image } sein.", 400);
    }
    if (!imageB64 || imageB64.length < 100) {
      return jsonError("Kein/zu kleines Bild übergeben.", 400);
    }
    // Falls ein Data-URI-Präfix mitkommt, abschneiden.
    const comma = imageB64.indexOf(",");
    if (imageB64.startsWith("data:") && comma !== -1) {
      imageB64 = imageB64.slice(comma + 1);
    }

    // ─── 3. Vorrat laden (für Abgleich) ─────────────────────────
    const { data: pantryRows } = await supabase
      .from("pantry_items")
      .select("name, category")
      .eq("status", "active");

    const pantry = (pantryRows ?? []) as PantryRow[];
    const pantryList = pantry.length > 0
      ? pantry.map((p) => `- ${p.name} [${p.category}]`).join("\n")
      : "(leer)";

    // ─── 4. Prompt + Gemini-Vision ──────────────────────────────
    const prompt =
      `Du bist ein Assistent in einer App gegen Lebensmittelverschwendung.
Auf dem Foto ist ein Lebensmittel-Einkauf (z.B. auf der Theke oder im Kühlschrank).

AUFGABE: Erkenne ALLE Lebensmittel auf dem Bild. Ignoriere alles, was kein
Lebensmittel ist (Hände, Tüten, Hintergrund, Geschirr).

Fasse mehrere gleiche Stücke zu EINEM Eintrag zusammen (z.B. 3 Bananen →
ein Eintrag, quantity "3 Stück").

VORHANDENER VORRAT DES NUTZERS:
${pantryList}

Gleiche jedes erkannte Lebensmittel mit diesem Vorrat ab:
- Wenn es dort schon existiert (auch andere Schreibweise, Ein-/Mehrzahl,
  Marke vs. generisch), setze "status": "schon_da" und "matched_name" auf
  den EXAKTEN Namen aus der Vorratsliste.
- Sonst "status": "neu" und "matched_name": null.

Für jedes Lebensmittel:
- "name": generischer deutscher Name, Einzahl, ohne Marke (z.B. "Banane",
  "Vollmilch", "Hähnchenbrust").
- "category": genau einer dieser Werte: ${CATEGORIES.join(", ")}.
- "quantity": geschätzte Menge als kurzer String (z.B. "3 Stück", "500 g")
  oder null, wenn unklar.
- "expiry_days": typische Haltbarkeit AB HEUTE in Tagen als ganze Zahl
  (z.B. Banane 5, Apfel 21, Blattsalat 4, Hackfleisch 2, Joghurt 14).
  Für lange haltbare Grundnahrungsmittel (Salz, Zucker, Mehl, Öl, Nudeln,
  Konserven, Gewürze) gib null zurück — die tracken wir nicht nach Datum.

Antworte AUSSCHLIESSLICH mit gültigem JSON in genau diesem Format,
ohne Markdown, ohne Code-Fence:

{
  "items": [
    {
      "name": "Banane",
      "category": "Obst",
      "quantity": "3 Stück",
      "expiry_days": 5,
      "status": "neu",
      "matched_name": null
    }
  ]
}`;

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) return jsonError("GEMINI_API_KEY missing", 500);

    const geminiUrl =
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`;

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              { inlineData: { mimeType, data: imageB64 } },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
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
    const text = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    let parsed: { items: unknown };
    try {
      parsed = JSON.parse(text);
    } catch (_e) {
      return jsonError(
        `Konnte Gemini-Antwort nicht parsen. Roh: ${text.slice(0, 300)}`,
        502,
      );
    }

    if (!parsed || !Array.isArray(parsed.items)) {
      return jsonError("Antwortformat ungültig (keine items-Liste)", 502);
    }

    // Server-seitig leicht säubern: Kategorie auf erlaubte Werte zwingen.
    const items = (parsed.items as Record<string, unknown>[]).map((it) => {
      const category = typeof it.category === "string" &&
          CATEGORIES.includes(it.category)
        ? it.category
        : "Sonstiges";
      const status = it.status === "schon_da" ? "schon_da" : "neu";
      return {
        name: typeof it.name === "string" ? it.name : "Unbekannt",
        category,
        quantity: typeof it.quantity === "string" ? it.quantity : null,
        expiry_days: typeof it.expiry_days === "number"
          ? Math.round(it.expiry_days)
          : null,
        status,
        matched_name: typeof it.matched_name === "string"
          ? it.matched_name
          : null,
      };
    });

    return jsonOk({ items, pantry_size: pantry.length });
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
