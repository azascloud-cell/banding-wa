class InboxMessage {
  final String from;
  final String subject;
  final String preview;

  /// Nomor tiket dari subject "WhatsApp Support XXXX" — null jika bukan email WA
  final String? ticketNumber;

  const InboxMessage({
    required this.from,
    required this.subject,
    required this.preview,
    this.ticketNumber,
  });

  @override
  String toString() =>
      'InboxMessage(from: $from, subject: $subject, ticketNumber: $ticketNumber)';
}
