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
  /// Returns a user-friendly Spanish error message from a technical Odoo error.
  static String getFriendlyError(dynamic e) {
    final String error = e.toString().toLowerCase();

    if (error.contains("attendance_pin")) {
      return "Attendance PIN is not supported by your Odoo version.";
    }
    if (error.contains("access denied") || error.contains("no tienes permiso")) {
      return "You do not have permission to perform this action.";
    }
    if (error.contains("signature")) {
      return "There was an error with the signature format.";
    }
    if (error.contains("connection") || error.contains("socketexception")) {
      return "Could not connect to the server. Please check your internet connection.";
    }
    if (error.contains("timeout")) {
      return "The server took too long to respond.";
    }
    if (error.contains("validation error") || error.contains("valor no válido")) {
      return "The entered data is not valid for Odoo.";
    }
    if (error.contains("serialization") || error.contains("utf-8")) {
      return "There is a problem with the data format (special characters).";
    }

    // Fallback cleaner for OdooServiceException
    if (e.toString().contains("OdooServiceException:")) {
      return e.toString().split("OdooServiceException:").last.trim();
    }

    return "An unexpected error occurred. Please try again.";
  }

  /// Returns empty string if Odoo sends false/null for a many2one field,
  /// otherwise returns the name (the second element of the [id, name] list).
  static String safeM2OName(dynamic value) {
    if (value is List && value.length >= 2) {
      return safeString(value[1]);
    }
    return '';
  }
}
