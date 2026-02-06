class OdooUtils {
  /// Returns empty string if Odoo sends false/null, otherwise returns the string value.
  /// This handles Odoo's distinct behavior of returning `false` for empty Text/Char fields.
  static String safeString(dynamic value) {
    if (value == null || value is bool) {
      return '';
    }
    return value.toString();
  }
}
