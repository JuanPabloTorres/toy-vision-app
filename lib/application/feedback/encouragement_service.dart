class EncouragementService {
  int _index = 0;

  static const List<String> _phrases = [
    '¡Muy bien!',
    '¡Encontraste otro!',
    '¡Excelente!',
    '¡Sigue así!',
    '¡Cada vez quedan menos!',
  ];

  String next() {
    final phrase = _phrases[_index % _phrases.length];
    _index += 1;
    return phrase;
  }

  void reset() => _index = 0;
}
