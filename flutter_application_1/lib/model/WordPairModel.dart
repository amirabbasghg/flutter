class WordPairModel {
    final String first;
    final String second;

    WordPairModel({required this.first, required this.second});

    String get asLowerCase => '$first $second'.toLowerCase();

    @override
    bool operator ==(Object other) =>
        identical(this, other) ||
            other is WordPairModel &&
                runtimeType == other.runtimeType &&
                first == other.first &&
                second == other.second;

    @override
    int get hashCode => first.hashCode ^ second.hashCode;
}