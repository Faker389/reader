/// Public-domain classics bundled with the app so the reader can be tried
/// immediately. Texts come from Project Gutenberg with the Gutenberg header
/// and licence removed (see tool/prepare_samples.dart).
class SampleBook {
  const SampleBook({
    required this.id,
    required this.title,
    required this.author,
    required this.asset,
    required this.description,
    required this.year,
  });

  final String id;
  final String title;
  final String author;
  final String asset;
  final String description;
  final int year;
}

abstract final class SampleBooks {
  /// Bump to re-seed sample books after changing the bundled texts.
  static const int version = 1;

  static const List<SampleBook> all = [
    SampleBook(
      id: 'sample_alice',
      title: "Alice's Adventures in Wonderland",
      author: 'Lewis Carroll',
      asset: 'assets/books/alice.txt',
      description: 'A curious girl follows a white rabbit into a world of riddles and nonsense.',
      year: 1865,
    ),
    SampleBook(
      id: 'sample_gatsby',
      title: 'The Great Gatsby',
      author: 'F. Scott Fitzgerald',
      asset: 'assets/books/gatsby.txt',
      description: 'Glittering parties, old money and a green light across the bay.',
      year: 1925,
    ),
    SampleBook(
      id: 'sample_pride',
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      asset: 'assets/books/pride.txt',
      description: 'Elizabeth Bennet, Mr. Darcy and the comedy of first impressions.',
      year: 1813,
    ),
    SampleBook(
      id: 'sample_meditations',
      title: 'Meditations',
      author: 'Marcus Aurelius',
      asset: 'assets/books/meditations.txt',
      description: "A Roman emperor's private notes on duty, calm and the shortness of life.",
      year: 180,
    ),
    SampleBook(
      id: 'sample_sherlock',
      title: 'The Adventures of Sherlock Holmes',
      author: 'Arthur Conan Doyle',
      asset: 'assets/books/sherlock.txt',
      description: 'Twelve cases from 221B Baker Street.',
      year: 1892,
    ),
  ];

  static SampleBook? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
