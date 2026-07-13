/// Gemeinsame Statuscode-Klassifikation für Edge-Function-Aufrufe,
/// damit alle Services dieselben Codes als „Dienst down" werten.
library;

/// Server-/Gateway-Fehler: die Edge Function bzw. der dahinterliegende
/// KI-Dienst ist gerade nicht erreichbar oder überlastet.
const Set<int> _serverDownStatuses = {500, 502, 503, 504};

/// True, wenn [status] „gerade nicht erreichbar" bedeutet — dann zeigt
/// das UI einen „später nochmal versuchen"-Hinweis statt eines
/// generischen Fehlers.
bool isEdgeFunctionDown(int? status) =>
    status != null && _serverDownStatuses.contains(status);
