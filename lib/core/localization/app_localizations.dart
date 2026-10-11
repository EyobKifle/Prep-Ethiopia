import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/auth_provider.dart';

// Riverpod provider for the current language code (defaults to 'am')
final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  final authState = ref.watch(authProvider);
  return LocaleNotifier(authState, ref);
});

class LocaleNotifier extends StateNotifier<String> {
  final AuthState _authState;
  final Ref _ref;

  LocaleNotifier(this._authState, this._ref) : super('en') {
    _initLocale();
  }

  void _initLocale() {
    if (_authState.profile != null) {
      state = _authState.profile!.preferredLanguage;
    }
  }

  Future<void> setLocale(String languageCode) async {
    if (languageCode == 'en' || languageCode == 'am') {
      state = languageCode;

      final profile = _authState.profile;
      if (profile != null) {
        profile.preferredLanguage = languageCode;
        profile.updatedAt = DateTime.now();
        profile.isDirty = true;

        await _ref.read(authProvider.notifier).updateProfile(profile);
      }
    }
  }

  void toggleLocale() {
    state = state == 'am' ? 'en' : 'am';
  }
}

class AppTranslations {
  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'Lumo',
      'welcome': 'Hello',
      'welcomeSubtitle': 'Ready to learn today?',
      'continueLearning': 'Continue Learning',
      'syncNow': 'SYNC NOW',
      'syncing': 'Syncing...',
      'synced': 'Synced',
      'pendingSync': 'Pending Sync',
      'offline': 'Offline',
      'lastSynced': 'Last synced',
      'never': 'Never',
      'streakDays': '{} Day Streak',
      'gradeNotSet': 'Grade Not Set',
      'pleaseSelectGrade': 'Please select your grade to continue',
      'tagline': 'Structured Learning. Anywhere.',
      'selectRole': 'Select your role to continue',
      'roleStudent': "I'm a Student",
      'roleParent': "I'm a Parent",
      'roleTeacher': "I'm a Teacher",
      'alreadyHaveAccount': 'Already have an account? Sign In',
      'studentSubtitle': 'Learn, take quizzes, and track progress',
      'parentSubtitle': "Monitor your child's educational journey",
      'teacherSubtitle': 'Manage content and view student analytics',
      
      // Onboarding
      'selectLanguage': 'Select Your Language',
      'selectLanguageSubtitle': 'Choose preferred language for app interface and textbooks',
      'selectGrade': 'Select Your Grade',
      'selectGradeSubtitle': 'Which class are you currently in?',
      'downloadResources': 'Download Course Materials',
      'downloadSubtitle': 'We are preparing your offline library...',
      'getStarted': 'Get Started',
      'next': 'Next',
      'back': 'Back',
      'finish': 'Finish',

      // Navigation
      'navHome': 'Home',
      'navSubjects': 'Subjects',
      'navSearch': 'Search',
      'navAnalysis': 'Analysis',
      'navExercises': 'Exercises',
      'navLibrary': 'Offline Library',
      'navProfile': 'Profile',
      'navAiTutor': 'AI Tutor',
      
      // Subject detail / Mode Toggle
      'officialTextbooks': 'Official Textbooks',
      'structuredLearning': 'Structured Learning',
      'downloadTextbook': 'Download Textbook',
      'deleteTextbook': 'Delete from Storage',
      'downloaded': 'Downloaded',
      'notDownloaded': 'Tap to download',
      'readStep': 'Read',
      'quizStep': 'Quiz',
      'flashcardStep': 'Flashcards',

      // Search
      'searchHint': 'Search for lessons, subjects...',

      // Exercises & Attempts
      'worksheets': 'Worksheets',
      'worksheetAttempts': 'Worksheet Attempts',
      'noWorksheets': 'No worksheets uploaded yet for this subject.',
      'score': 'Score',
      'timer': 'Timer',
      'submit': 'Submit',
      'submitSuccess': 'Attempt Submitted Successfully!',
      'reviewAnswers': 'Review Answers',
      'correctAnswer': 'Correct Answer',
      'explanation': 'Explanation',
      'allQuestions': 'All Questions',
      'incorrectOnly': 'Incorrect Only',
      'correctOnly': 'Correct Only',
      
      // Flashcards
      'tapToFlip': 'TAP TO FLIP',
      'mnemonic': 'Mnemonic Helper',
      'flashcardHard': 'Hard',
      'flashcardGood': 'Good',
      'flashcardEasy': 'Easy',
      'flashcardComplete': 'Flashcard Review Complete!',

      // Library / Storage
      'libraryTitle': 'Offline Storage Manager',
      'storageUsage': 'Using {} of estimated 2 GB space',
      'downloadAll': 'Download All',
      'deleteAll': 'Delete All',
      
      // Settings / Profile
      'parentCode': 'Parent Link Code',
      'parentCodeSubtitle': 'Share this code with your parent to link accounts',
      'languageSetting': 'App Language',
      'themeSetting': 'Theme Mode',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'themeSystem': 'System Default',
      'signOut': 'Sign Out',
      'guestMode': 'Guest Mode',
      'guestProfileMsg': 'You are currently using the app as a guest. Your progress is saved locally but won\'t be synced.',
      'createAccount': 'Create Account',
      'signIn': 'Sign In',

      // Parent Portal
      'parentDashboard': 'Parent Dashboard',
      'myChildren': 'My Children',
      'addChild': 'Add Child',
      'linkChildCode': 'Enter 6-digit Student Code',
      'link': 'Link Student',
      'averageQuizScore': 'Avg Quiz Score',
      'weeklyStudyTime': 'Study Time (This Week)',
      'recentActivities': 'Recent Activity Feed',
      'noChildrenLinked': 'You have not linked any student profiles yet.',

      // Admin Portal
      'adminDashboard': 'Admin Portal',
      'contentManager': 'Content Manager',
      'diagnostics': 'System Diagnostics',
      'featureFlags': 'Feature Toggles',
      'addGrade': 'Add Grade',
      'addSubject': 'Add Subject',
      'addUnit': 'Add Unit',
      'addLesson': 'Add Lesson',
      'uploadTextbook': 'Upload Textbook PDF',
      'publishStatus': 'Publish Settings',
      'logs': 'Audit and Diagnostics Logs',
      
      // Common UI States
      'emptyStateTitle': 'Nothing found here',
      'emptyStateSubtitle': 'It seems there is no data to show at the moment.',
      'retry': 'Retry',
      'errorOccurred': 'An error occurred',
      'loading': 'Loading...',
    },
    'am': {
      'appName': 'ሉሞ',
      'welcome': 'ሰላም',
      'welcomeSubtitle': 'ዛሬ ለመማር ዝግጁ ነዎት?',
      'continueLearning': 'ትምህርቱን ቀጥል',
      'syncNow': 'አሁን አመሳስል',
      'syncing': 'በማመሳሰል ላይ...',
      'synced': 'ተመሳስሏል',
      'pendingSync': 'ያልተመሳሰሉ መረጃዎች',
      'offline': 'ከመስመር ውጭ',
      'lastSynced': 'ለመጨረሻ ጊዜ የተመሳሰለው',
      'never': 'አልተመሳሰለም',
      'streakDays': '{} ቀናት ተከታታይ ጥናት',
      'gradeNotSet': 'ክፍል አልተዋቀረም',
      'pleaseSelectGrade': 'እባክዎ ለመቀጠል ክፍልዎን ይምረጡ',
      'tagline': 'በማናችሁም ቦታ የተዋቀረ ጥናት።',
      'selectRole': 'ሚናዎን ይምረጡ ለመቀጠል',
      'roleStudent': 'እኔ ተማሪ ነኝ',
      'roleParent': 'እኔ ወላጅ ነኝ',
      'roleTeacher': 'እኔ አስተማሪ ነኝ',
      'alreadyHaveAccount': 'መለያ አለዎት? ግቡ',
      'studentSubtitle': 'ይማሩ፣ ጥያቄዎችን ይመልሱ እና ረዕዮትን ይከታተሉ',
      'parentSubtitle': 'የልጅዎን የትምህርት ጉዞ ይከታተሉ',
      'teacherSubtitle': 'ይዘት ያስተዳድሩ እና የተማሪዎችን ትንተና ይመልከቱ',
      
      // Onboarding
      'selectLanguage': 'ቋንቋ ይምረጡ',
      'selectLanguageSubtitle': 'የመተግበሪያውን እና የመማሪያ መጽሐፍትን ቋንቋ ይምረጡ',
      'selectGrade': 'ክፍልዎን ይምረጡ',
      'selectGradeSubtitle': 'በአሁኑ ጊዜ በየትኛው ክፍል ውስጥ ነዎት?',
      'downloadResources': 'የጥናት መርጃዎችን ያውርዱ',
      'downloadSubtitle': 'የእርስዎን የመማሪያ መጽሐፍት በማዘጋጀት ላይ ነን...',
      'getStarted': 'ጀምር',
      'next': 'ቀጣይ',
      'back': 'ወደ ኋላ',
      'finish': 'ጨርስ',

      // Navigation
      'navHome': 'ቤት',
      'navSubjects': 'ትምህርቶች',
      'navSearch': 'ፈልግ',
      'navAnalysis': 'ትንተና',
      'navExercises': 'መልመጃዎች',
      'navLibrary': 'የእኔ ላይብረሪ',
      'navProfile': 'መገለጫ',
      'navAiTutor': 'AI Tutor',
      
      // Subject detail / Mode Toggle
      'officialTextbooks': 'ይፋዊ መጽሐፍት',
      'structuredLearning': 'የተዋቀረ ጥናት',
      'downloadTextbook': 'መጽሐፉን አውርድ',
      'deleteTextbook': 'ከስልክ አጥፋ',
      'downloaded': 'ወርዷል',
      'notDownloaded': 'ለማውረድ ይንኩ',
      'readStep': 'ንባብ',
      'quizStep': 'ጥያቄዎች',
      'flashcardStep': 'ፍላሽ ካርዶች',

      // Search
      'searchHint': 'ትምህርቶችን፣ ምዕራፎችን ይፈልጉ...',

      // Exercises & Attempts
      'worksheets': 'ዎርክሺቶች',
      'worksheetAttempts': 'የዎርክሺት ውጤቶች',
      'noWorksheets': 'ለዚህ ትምህርት እስካሁን ዎርክሺት አልተጫነም።',
      'score': 'ውጤት',
      'timer': 'ሰዓት',
      'submit': 'አስረክብ',
      'submitSuccess': 'ውጤትዎ በተሳካ ሁኔታ ተመዝግቧል!',
      'reviewAnswers': 'መልሶችን ከልስ',
      'correctAnswer': 'ትክክለኛ መልስ',
      'explanation': 'ማብራሪያ',
      'allQuestions': 'ሁሉም ጥያቄዎች',
      'incorrectOnly': 'የተሳሳቱ ብቻ',
      'correctOnly': 'ትክክለኛ ብቻ',
      
      // Flashcards
      'tapToFlip': 'ለመገልበጥ ይንኩ',
      'mnemonic': 'አጋዥ ማስታወሻ',
      'flashcardHard': 'ከባድ',
      'flashcardGood': 'ጥሩ',
      'flashcardEasy': 'ቀላል',
      'flashcardComplete': 'የፍላሽ ካርድ ክለሳ ተጠናቋል!',

      // Library / Storage
      'libraryTitle': 'ስልክ ማከማቻ ማስተዳደሪያ',
      'storageUsage': 'ከሚገመተው 2 ጂቢ ውስጥ {} ጥቅም ላይ ውሏል',
      'downloadAll': 'ሁሉንም አውርድ',
      'deleteAll': 'ሁሉንም አጥፋ',
      
      // Settings / Profile
      'parentCode': 'የወላጅ ማገናኛ ኮድ',
      'parentCodeSubtitle': 'መለያዎችን ለማገናኘት ይህንን ኮድ ለወላጅዎ ያጋሩ',
      'languageSetting': 'የመተግበሪያ ቋንቋ',
      'themeSetting': 'ገጽታ',
      'themeLight': 'ብርሃን',
      'themeDark': 'ጨለማ',
      'themeSystem': 'የስልክ ገጽታ',
      'signOut': 'ውጣ',
      'guestMode': 'የእንግዳ ሁኔታ',
      'guestProfileMsg': 'በአሁኑ ጊዜ መተግበሪያውን እንደ እንግዳ እየተጠቀሙ ነው። የእርስዎ መረጃ በዚህ ስልክ ላይ ብቻ ነው የሚቀመጠው።',
      'createAccount': 'መለያ ፍጠር',
      'signIn': 'ግባ',

      // Parent Portal
      'parentDashboard': 'የወላጅ መቆጣጠሪያ',
      'myChildren': 'የእኔ ልጆች',
      'addChild': 'ልጅ አክል',
      'linkChildCode': 'የ 6-አሃዝ የተማሪ ኮድ ያስገቡ',
      'link': 'ተማሪውን አገናኝ',
      'averageQuizScore': 'አማካይ የፈተና ውጤት',
      'weeklyStudyTime': 'የጥናት ሰዓት (በዚህ ሳምንት)',
      'recentActivities': 'የቅርብ ጊዜ እንቅስቃሴዎች',
      'noChildrenLinked': 'እስካሁን ምንም የተማሪ መገለጫ አላገናኙም።',

      // Admin Portal
      'adminDashboard': 'የአስተዳዳሪ ክፍል',
      'contentManager': 'ይዘት ማስተዳደሪያ',
      'diagnostics': 'የስርዓት ሁኔታ',
      'featureFlags': 'የሙከራ ባህሪያት',
      'addGrade': 'ክፍል አክል',
      'addSubject': 'ትምህርት አክል',
      'addUnit': 'ምዕራፍ አክል',
      'addLesson': 'ትምህርት አክል',
      'uploadTextbook': 'የመጽሐፍ ፒዲኤፍ ጫን',
      'publishStatus': 'የስርጭት ሁኔታ',
      'logs': 'የስርዓት እና የእንቅስቃሴ ምዝግብ ማስታወሻዎች',
      
      // Common UI States
      'emptyStateTitle': 'ምንም አልተገኘም',
      'emptyStateSubtitle': 'በአሁኑ ጊዜ የሚታይ ምንም መረጃ የለም።',
      'retry': 'እንደገና ሞክር',
      'errorOccurred': 'ስህተት ተከስቷል',
      'loading': 'በመጫን ላይ...',
    }
  };

  static String translate(String key, String locale, {String? arg}) {
    final value = _localizedValues[locale]?[key] ?? _localizedValues['en']?[key] ?? key;
    if (arg != null) {
      return value.replaceAll('{}', arg);
    }
    return value;
  }
}

extension BuildContextTranslation on BuildContext {
  String tr(String key, {String? arg}) {
    // Obtain language code from Riverpod state
    final container = ProviderScope.containerOf(this);
    final locale = container.read(localeProvider);
    return AppTranslations.translate(key, locale, arg: arg);
  }

  String get currentLocale {
    final container = ProviderScope.containerOf(this);
    return container.read(localeProvider);
  }
}
