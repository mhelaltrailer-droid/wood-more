/// حد أقصى لحجم كل مرفق MS-SD (5 ميجابايت).
const int kMsSdMaxFileBytes = 5 * 1024 * 1024;

String msSdMaxFileSizeLabel() => '5 ميجابايت';

bool msSdFileWithinLimit(int byteLength) => byteLength <= kMsSdMaxFileBytes;
