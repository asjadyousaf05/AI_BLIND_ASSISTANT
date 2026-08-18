/// Reading profiles designed for blind and visually impaired users.
enum ReadingProfile {
  learning(
    0.35,
    'Learning mode: slow and clear with distinct sentence pauses.',
    Duration(milliseconds: 600),
  ),
  normal(
    0.50,
    'Normal mode: standard conversational reading speed.',
    Duration(milliseconds: 450),
  ),
  skim(
    0.75,
    'Skim mode: fast reading for quickly reviewing text.',
    Duration(milliseconds: 250),
  ),
  spell(
    0.40,
    'Spell mode: spelling words letter by letter.',
    Duration(milliseconds: 500),
  );

  const ReadingProfile(this.speechRate, this.description, this.pauseDuration);

  final double speechRate;
  final String description;
  final Duration pauseDuration;

  double get rate => speechRate;

  String get label => switch (this) {
    ReadingProfile.learning => 'Learning (Slow)',
    ReadingProfile.normal => 'Normal',
    ReadingProfile.skim => 'Skim (Fast)',
    ReadingProfile.spell => 'Spell',
  };
}
