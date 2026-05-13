
class AppSession {
  AppSession._();
  static final AppSession _instance = AppSession._();
  static AppSession get instance => _instance;

  int?    userId;
  String? username;
  String? fullName;
  String? role;

  // Sub-admin permission flags (only meaningful when role == 'sub_admin')
  bool permAdmin        = false; // can access Admin sidebar section
  bool permEditDetails  = false; // can edit job / team / personnel details
  bool permEditReports  = false; // can edit monthly / overall / relocation reports

  void set(
      int id,
      String uname,
      String name, {
        String userRole       = 'user',
        bool   pAdmin         = false,
        bool   pEditDetails   = false,
        bool   pEditReports   = false,
      }) {
    userId   = id;
    username = uname;
    fullName = name;
    role     = userRole;
    permAdmin       = pAdmin;
    permEditDetails = pEditDetails;
    permEditReports = pEditReports;
  }

  void clear() {
    userId   = null;
    username = null;
    fullName = null;
    role     = null;
    permAdmin       = false;
    permEditDetails = false;
    permEditReports = false;
  }

  bool get isLoggedIn => userId != null;
  bool get isAdmin    => role == 'admin';
  bool get isSubAdmin => role == 'sub_admin';

  /// True for full admins AND sub-admins who have the admin-panel permission.
  bool get canAccessAdmin  => isAdmin || (isSubAdmin && permAdmin);

  /// True for full admins AND sub-admins who have the edit-reports permission.
  bool get canEditReports  => isAdmin || (isSubAdmin && permEditReports);

  /// First letter of fullName for avatar.
  String get initial => (fullName?.isNotEmpty == true)
      ? fullName![0].toUpperCase()
      : (username?.isNotEmpty == true ? username![0].toUpperCase() : 'U');
}