class EvidenceStorageException implements Exception {
  final String message;
  final String? code;

  const EvidenceStorageException(this.message, {this.code});

  @override
  String toString() => 'EvidenceStorageException: $message';
}

class EvidenceStorageValidationException extends EvidenceStorageException {
  const EvidenceStorageValidationException(super.message)
      : super(code: 'VALIDATION_ERROR');
}

class EvidenceStoragePathException extends EvidenceStorageException {
  const EvidenceStoragePathException(super.message)
      : super(code: 'PATH_SECURITY_VIOLATION');
}

class EvidenceStorageNotFoundException extends EvidenceStorageException {
  const EvidenceStorageNotFoundException(super.message)
      : super(code: 'NOT_FOUND');
}

class EvidenceStorageUnavailableException extends EvidenceStorageException {
  const EvidenceStorageUnavailableException(super.message)
      : super(code: 'UNAVAILABLE');
}
