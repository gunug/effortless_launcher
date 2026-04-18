const List<String> _chosungList = [
  'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
];

const List<String> _jungseongList = [
  'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ',
];

const List<String> _jongseongList = [
  '','ㄱ','ㄲ','ㄳ','ㄴ','ㄵ','ㄶ','ㄷ','ㄹ','ㄺ','ㄻ','ㄼ','ㄽ','ㄾ','ㄿ','ㅀ','ㅁ','ㅂ','ㅄ','ㅅ','ㅆ','ㅇ','ㅈ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
];

const List<String> _choToRoman = [
  'g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h',
];

const List<String> _jungToRoman = [
  'a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u','wo','we','wi','yu','eu','ui','i',
];

const List<String> _jongToRoman = [
  '','k','kk','ks','n','nj','nh','t','l','lg','lm','lb','ls','lt','lp','lh','m','p','ps','s','ss','ng','j','ch','k','t','p','h',
];

const Map<String, String> _jamoToRoman = {
  'ㄱ':'g','ㄲ':'kk','ㄴ':'n','ㄷ':'d','ㄸ':'tt','ㄹ':'r','ㅁ':'m','ㅂ':'b','ㅃ':'pp',
  'ㅅ':'s','ㅆ':'ss','ㅇ':'','ㅈ':'j','ㅉ':'jj','ㅊ':'ch','ㅋ':'k','ㅌ':'t','ㅍ':'p','ㅎ':'h',
  'ㄳ':'ks','ㄵ':'nj','ㄶ':'nh','ㄺ':'lg','ㄻ':'lm','ㄼ':'lb','ㄽ':'ls','ㄾ':'lt','ㄿ':'lp','ㅀ':'lh','ㅄ':'ps',
  'ㅏ':'a','ㅐ':'ae','ㅑ':'ya','ㅒ':'yae','ㅓ':'eo','ㅔ':'e','ㅕ':'yeo','ㅖ':'ye',
  'ㅗ':'o','ㅛ':'yo','ㅜ':'u','ㅠ':'yu','ㅡ':'eu','ㅣ':'i',
  'ㅘ':'wa','ㅙ':'wae','ㅚ':'oe','ㅝ':'wo','ㅞ':'we','ㅟ':'wi','ㅢ':'ui',
};

const Map<String, String> _jamoToQwerty = {
  'ㄱ':'r','ㄲ':'R','ㄴ':'s','ㄷ':'e','ㄸ':'E','ㄹ':'f','ㅁ':'a','ㅂ':'q','ㅃ':'Q',
  'ㅅ':'t','ㅆ':'T','ㅇ':'d','ㅈ':'w','ㅉ':'W','ㅊ':'c','ㅋ':'z','ㅌ':'x','ㅍ':'v','ㅎ':'g',
  'ㄳ':'rt','ㄵ':'sw','ㄶ':'sg','ㄺ':'fr','ㄻ':'fa','ㄼ':'fq','ㄽ':'ft','ㄾ':'fx','ㄿ':'fv','ㅀ':'fg','ㅄ':'qt',
  'ㅏ':'k','ㅐ':'o','ㅑ':'i','ㅒ':'O','ㅓ':'j','ㅔ':'p','ㅕ':'u','ㅖ':'P',
  'ㅗ':'h','ㅛ':'y','ㅜ':'n','ㅠ':'b','ㅡ':'m','ㅣ':'l',
  'ㅘ':'hk','ㅙ':'ho','ㅚ':'hl','ㅝ':'nj','ㅞ':'np','ㅟ':'nl','ㅢ':'ml',
};

bool _isHangulSyllable(int code) => code >= 0xAC00 && code <= 0xD7A3;

String extractChosung(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (_isHangulSyllable(r)) {
      sb.write(_chosungList[(r - 0xAC00) ~/ 588]);
    } else {
      final c = String.fromCharCode(r);
      if (_chosungList.contains(c)) {
        sb.write(c);
      }
    }
  }
  return sb.toString();
}

bool isAllChosung(String q) {
  if (q.isEmpty) return false;
  var hasAny = false;
  for (final r in q.runes) {
    final c = String.fromCharCode(r);
    if (c == ' ') continue;
    if (!_chosungList.contains(c)) return false;
    hasAny = true;
  }
  return hasAny;
}

String romanize(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (_isHangulSyllable(r)) {
      final code = r - 0xAC00;
      final cho = code ~/ 588;
      final jung = (code % 588) ~/ 28;
      final jong = code % 28;
      sb.write(_choToRoman[cho]);
      sb.write(_jungToRoman[jung]);
      if (jong > 0) sb.write(_jongToRoman[jong]);
    } else {
      final c = String.fromCharCode(r);
      sb.write(_jamoToRoman[c] ?? c);
    }
  }
  return sb.toString().toLowerCase();
}

int longestCommonSubstring(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final n = a.length;
  final m = b.length;
  var prev = List<int>.filled(m + 1, 0);
  var curr = List<int>.filled(m + 1, 0);
  var best = 0;
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      if (a[i - 1] == b[j - 1]) {
        curr[j] = prev[j - 1] + 1;
        if (curr[j] > best) best = curr[j];
      } else {
        curr[j] = 0;
      }
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
    for (var k = 0; k <= m; k++) {
      curr[k] = 0;
    }
  }
  return best;
}

int editDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  final n = a.length;
  final m = b.length;
  var prev = List<int>.generate(m + 1, (i) => i);
  final curr = List<int>.filled(m + 1, 0);
  for (var i = 1; i <= n; i++) {
    curr[0] = i;
    for (var j = 1; j <= m; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      var min = del < ins ? del : ins;
      if (sub < min) min = sub;
      curr[j] = min;
    }
    for (var k = 0; k <= m; k++) {
      prev[k] = curr[k];
    }
  }
  return prev[m];
}

int minEditDistanceWindow(String pattern, String text) {
  if (pattern.isEmpty) return 0;
  final n = pattern.length;
  if (text.length < n - 1) return n;
  var best = n;
  final sizes = [n - 1, n, n + 1];
  for (final size in sizes) {
    if (size <= 0 || size > text.length) continue;
    for (var i = 0; i <= text.length - size; i++) {
      final d = editDistance(pattern, text.substring(i, i + size));
      if (d < best) best = d;
      if (best == 0) return 0;
    }
  }
  return best;
}

bool isSubsequence(String pattern, String text) {
  if (pattern.isEmpty) return true;
  var i = 0;
  for (var j = 0; j < text.length && i < pattern.length; j++) {
    if (text[j] == pattern[i]) i++;
  }
  return i == pattern.length;
}

int subsequenceSpread(String pattern, String text) {
  if (pattern.isEmpty) return 0;
  var first = -1;
  var last = -1;
  var i = 0;
  for (var j = 0; j < text.length && i < pattern.length; j++) {
    if (text[j] == pattern[i]) {
      if (first == -1) first = j;
      last = j;
      i++;
    }
  }
  if (first < 0 || i < pattern.length) return text.length;
  return last - first;
}

String extractInitials(String name) {
  final sb = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    final isLetter = (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5A) ||
        (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A);
    if (!isLetter) continue;
    if (i == 0) {
      sb.write(c.toLowerCase());
      continue;
    }
    final prev = name[i - 1];
    final isWordStart = prev == ' ' || prev == '\t' || prev == '-' || prev == '_' || prev == '.';
    final prevLower = prev.toLowerCase() == prev && prev.toUpperCase() != prev;
    final cUpper = c.toUpperCase() == c && c.toLowerCase() != c;
    if (isWordStart || (prevLower && cUpper)) {
      sb.write(c.toLowerCase());
    }
  }
  return sb.toString();
}

int wordBoundaryBonusAt(String haystack, int pos) {
  if (pos == 0) return 1000;
  if (pos < 0 || pos >= haystack.length) return 0;
  final prev = haystack[pos - 1];
  if (prev == ' ' || prev == '\t' || prev == '-' || prev == '_' || prev == '.') {
    return 500;
  }
  return 0;
}

int commonCharCount(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final setA = <String>{};
  for (var i = 0; i < a.length; i++) {
    final c = a[i];
    if (c != ' ') setA.add(c);
  }
  final setB = <String>{};
  for (var i = 0; i < b.length; i++) {
    final c = b[i];
    if (c != ' ') setB.add(c);
  }
  return setA.intersection(setB).length;
}

String toQwerty(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (_isHangulSyllable(r)) {
      final code = r - 0xAC00;
      final cho = code ~/ 588;
      final jung = (code % 588) ~/ 28;
      final jong = code % 28;
      sb.write(_jamoToQwerty[_chosungList[cho]] ?? '');
      sb.write(_jamoToQwerty[_jungseongList[jung]] ?? '');
      if (jong > 0) sb.write(_jamoToQwerty[_jongseongList[jong]] ?? '');
    } else {
      final c = String.fromCharCode(r);
      sb.write(_jamoToQwerty[c] ?? c);
    }
  }
  return sb.toString().toLowerCase();
}
