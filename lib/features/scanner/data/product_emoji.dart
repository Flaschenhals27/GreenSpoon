/// Smart-Emoji-Picker basierend auf Produktnamen und Kategorie.
///
/// Logik:
/// 1. Versuche, einen Treffer aus dem Produktnamen zu finden (z.B. "Spezi" → 🥤)
/// 2. Falls keiner: nimm das Kategorie-Default-Emoji
/// 3. Falls auch keine Kategorie matched: 📦
class ProductEmojiResolver {
  ProductEmojiResolver._();

  /// Reihenfolge ist wichtig: spezifischere Begriffe zuerst.
  /// Begriffe in **lowercase**, Matching ist case-insensitive.
  static const _nameKeywords = <String, String>{
    // ─── Milchprodukte ────────────────────────────────────────
    'skyr': '🥛',
    'joghurt': '🥛',
    'jogurt': '🥛',
    'milch': '🥛',
    'sahne': '🥛',
    'quark': '🥛',
    'frischkäse': '🧀',
    'käse': '🧀',
    'butter': '🧈',
    'mozzarella': '🧀',
    'feta': '🧀',
    'parmesan': '🧀',
    'gouda': '🧀',
    'ricotta': '🧀',

    // ─── Obst ─────────────────────────────────────────────────
    'apfel': '🍎',
    'apfelmus': '🍎',
    'birne': '🍐',
    'banane': '🍌',
    'erdbeer': '🍓',
    'himbeer': '🫐',
    'heidelbeer': '🫐',
    'blaubeer': '🫐',
    'kirsch': '🍒',
    'aprikos': '🍑',
    'pfirsich': '🍑',
    'zitrone': '🍋',
    'limette': '🍋',
    'orange': '🍊',
    'mandarine': '🍊',
    'clementine': '🍊',
    'traube': '🍇',
    'wein': '🍇',
    'mango': '🥭',
    'ananas': '🍍',
    'melone': '🍈',
    'wasserm': '🍉',
    'kiwi': '🥝',
    'avocado': '🥑',
    'kokos': '🥥',
    'granatapfel': '🍎',
    'datteln': '🌴',

    // ─── Gemüse ───────────────────────────────────────────────
    'tomate': '🍅',
    'gurke': '🥒',
    'paprika': '🫑',
    'salat': '🥬',
    'spinat': '🥬',
    'rucola': '🥬',
    'feldsalat': '🥬',
    'eisberg': '🥬',
    'kohl': '🥬',
    'brokkoli': '🥦',
    'blumenkohl': '🥦',
    'rosenkohl': '🥦',
    'karotte': '🥕',
    'möhre': '🥕',
    'mohrrübe': '🥕',
    'kartoffel': '🥔',
    'süßkartoffel': '🍠',
    'mais': '🌽',
    'erbse': '🫛',
    'bohne': '🫘',
    'kichererbse': '🫘',
    'linse': '🫘',
    'zwiebel': '🧅',
    'lauch': '🧅',
    'porree': '🧅',
    'knoblauch': '🧄',
    'ingwer': '🫚',
    'pilz': '🍄',
    'champignon': '🍄',
    'aubergine': '🍆',
    'zucchini': '🥒',
    'kürbis': '🎃',
    'rote bete': '🥕',
    'sellerie': '🥬',
    'fenchel': '🥬',
    'spargel': '🥬',
    'chili': '🌶',
    'peperoni': '🌶',
    'oliv': '🫒',

    // ─── Fleisch & Fisch ──────────────────────────────────────
    'hähnchen': '🍗',
    'huhn': '🍗',
    'pute': '🍗',
    'truthahn': '🍗',
    'ente': '🍗',
    'rind': '🥩',
    'steak': '🥩',
    'gulasch': '🥩',
    'hackfleisch': '🥩',
    'hack': '🥩',
    'schwein': '🥓',
    'speck': '🥓',
    'schinken': '🥓',
    'salami': '🥓',
    'wurst': '🌭',
    'bratwurst': '🌭',
    'mortadella': '🥩',
    'lachs': '🐟',
    'thunfisch': '🐟',
    'forelle': '🐟',
    'kabeljau': '🐟',
    'fisch': '🐟',
    'garnel': '🦐',
    'shrimp': '🦐',

    // ─── Pasta, Reis, Mehl, Getreide ─────────────────────────
    'pasta': '🍝',
    'nudel': '🍝',
    'spaghetti': '🍝',
    'penne': '🍝',
    'tortellini': '🍝',
    'lasagne': '🍝',
    'gnocchi': '🥟',
    'ravioli': '🥟',
    'reis': '🍚',
    'risotto': '🍚',
    'couscous': '🍚',
    'bulgur': '🍚',
    'quinoa': '🍚',
    'mehl': '🌾',
    'haferflocken': '🥣',
    'haferb': '🥣',
    'müsli': '🥣',
    'cornflakes': '🥣',
    'granola': '🥣',
    'porridge': '🥣',

    // ─── Brot & Backwaren ────────────────────────────────────
    'toast': '🍞',
    'brot': '🍞',
    'vollkorntoast': '🍞',
    'vollkorn': '🍞',
    'brötchen': '🥐',
    'baguette': '🥖',
    'croissant': '🥐',
    'bagel': '🥯',
    'zwieback': '🍞',
    'knäckebrot': '🍞',

    // ─── Eier ─────────────────────────────────────────────────
    'ei ': '🥚',
    'eier': '🥚',

    // ─── Süßes & Snacks ───────────────────────────────────────
    'schokolad': '🍫',
    'schoko': '🍫',
    'kekse': '🍪',
    'keks': '🍪',
    'cookie': '🍪',
    'kuchen': '🍰',
    'torte': '🍰',
    'donut': '🍩',
    'gummibär': '🍬',
    'bonbon': '🍬',
    'lutscher': '🍭',
    'eis': '🍦',
    'sorbet': '🍦',
    'chips': '🍿',
    'popcorn': '🍿',
    'nuss': '🥜',
    'erdnuss': '🥜',
    'mandel': '🥜',
    'cashew': '🥜',
    'honig': '🍯',
    'marmelad': '🍓',
    'nutella': '🍫',

    // ─── Getränke ────────────────────────────────────────────
    'wasser': '💧',
    'mineralwasser': '💧',
    'sprudel': '💧',
    'spezi': '🥤',
    'cola': '🥤',
    'limonade': '🥤',
    'limo': '🥤',
    'fanta': '🥤',
    'sprite': '🥤',
    'softdrink': '🥤',
    'saft': '🧃',
    'apfelsaft': '🧃',
    'orangensaft': '🧃',
    'smoothie': '🧃',
    'kaffee': '☕',
    'espresso': '☕',
    'cappuccino': '☕',
    'tee': '🍵',
    'matcha': '🍵',
    'bier': '🍺',
    'pils': '🍺',
    'weizen': '🍺',
    'sekt': '🍾',
    'prosecco': '🍾',
    'rotwein': '🍷',
    'weißwein': '🍷',
    'cocktail': '🍹',

    // ─── Tiefkühl ────────────────────────────────────────────
    'pizza': '🍕',
    'pommes': '🍟',

    // ─── Gewürze, Saucen, Öle ────────────────────────────────
    'olivenöl': '🫒',
    'sonnenblumenöl': '🌻',
    'salz': '🧂',
    'pfeffer': '🧂',
    'zucker': '🍬',
    'essig': '🍶',
    'sojasauce': '🍶',
    'ketchup': '🍅',
    'mayonn': '🥫',
    'senf': '🥫',
    'tomatensauce': '🥫',
    'pesto': '🌿',

    // ─── Dosen & Konserven ───────────────────────────────────
    'dose': '🥫',
    'konserve': '🥫',
  };

  /// Default-Emoji für jede Kategorie (Fallback wenn kein Name-Treffer).
  static const _categoryDefaults = <String, String>{
    'Milchprodukte': '🥛',
    'Obst': '🍎',
    'Gemüse': '🥬',
    'Fleisch & Fisch': '🥩',
    'Pasta & Reis': '🍝',
    'Brot & Backwaren': '🍞',
    'Tiefkühl': '🧊',
    'Getränke': '🥤',
    'Eier': '🥚',
    'Müsli & Cerealien': '🥣',
    'Süßes & Snacks': '🍫',
    'Gewürze & Saucen': '🧂',
    'Konserven': '🥫',
    'Aufstriche': '🍯',
    'Sonstiges': '📦',
  };

  /// Liefert das passendste Emoji.
  ///
  /// [name] kann leer sein → dann reicht die Kategorie.
  /// [category] kann unbekannt sein → 📦.
  static String resolve({String? name, String? category}) {
    final lower = (name ?? '').toLowerCase();
    if (lower.isNotEmpty) {
      for (final entry in _nameKeywords.entries) {
        if (lower.contains(entry.key)) return entry.value;
      }
    }
    return _categoryDefaults[category] ?? '📦';
  }
}