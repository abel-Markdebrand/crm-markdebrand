class OdooUtils {
  /// Returns empty string if Odoo sends false/null, otherwise returns the string value.
  /// This handles Odoo's distinct behavior of returning `false` for empty Text/Char fields.
  static String safeString(dynamic value) {
    if (value == null || value is bool) {
      return '';
    }
    return value.toString();
  }

  /// Strips HTML tags from a string using regex.
  static String stripHtml(String html) {
    if (html.isEmpty) return '';
    // Remove HTML tags
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    String clean = html.replaceAll(exp, '');
    // Decode common entities roughly
    clean = clean.replaceAll('&nbsp;', ' ');
    clean = clean.replaceAll('&amp;', '&');
    clean = clean.replaceAll('&lt;', '<');
    clean = clean.replaceAll('&gt;', '>');
    clean = clean.replaceAll('&quot;', '"');
    return clean.trim();
  }

  /// Returns 0 if Odoo sends false/null, otherwise returns the integer value.
  static int safeInt(dynamic value) {
    if (value == null || value is bool) {
      return 0;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return (value as num).toInt();
  }

  /// Returns 0.0 if Odoo sends false/null, otherwise returns the double value.
  static double safeDouble(dynamic value) {
    if (value == null || value is bool) {
      return 0.0;
    }
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return (value as num).toDouble();
  }
}
