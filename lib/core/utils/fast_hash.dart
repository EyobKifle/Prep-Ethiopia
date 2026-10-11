/// Deterministic FNV-1a 32-bit hash algorithm to convert UUID strings
/// into unique 32-bit integers for Isar primary keys.
/// This is compatible with all Flutter platforms including web.
int fastHash(String uuid) {
  var hash = 0x811C9DC5; // 32-bit FNV offset basis
  for (var i = 0; i < uuid.length; i++) {
    hash ^= uuid.codeUnitAt(i);
    hash *= 0x01000193; // 32-bit FNV prime
    hash &= 0xFFFFFFFF; // Maintain 32-bit
  }
  return hash;
}
