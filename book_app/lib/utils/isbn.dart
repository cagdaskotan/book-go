bool isValidBookISBN13(String value) {
  if (!RegExp(r'^97[89]\d{10}$').hasMatch(value)) return false;
  var sum = 0;
  for (var index = 0; index < 12; index++) {
    sum += int.parse(value[index]) * (index.isEven ? 1 : 3);
  }
  final expected = (10 - (sum % 10)) % 10;
  return expected == int.parse(value[12]);
}
