import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Kitap kapağı fotoğrafı.
///
/// Türkçe baskıların çoğu Google Books ve Open Library'de yok; barkod
/// tutmadığında kapak da gelmiyor. Kapaksız kitaplarla dolu bir raf, bu
/// uygulamanın en iyi olduğu şeyi — rafın kendisini — öldürüyor. Bu yüzden
/// kullanıcı kapağı kendi çekebiliyor.
///
/// Çekilen görsel uygulamanın belge klasöründe `covers/` altında saklanır:
/// cihazın galerisi kirlenmez, dosya uygulamayla birlikte silinir.
class CoverPhotoService {
  CoverPhotoService._();

  static final ImagePicker _picker = ImagePicker();

  /// Kamerayla kapak çeker. Kullanıcı vazgeçerse null döner.
  static Future<String?> capture() => _pick(ImageSource.camera);

  /// Galeriden kapak seçer. Kullanıcı vazgeçerse null döner.
  static Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  static Future<String?> _pick(ImageSource source) async {
    final shot = await _picker.pickImage(
      source: source,
      // Kapak için 1200 piksel fazlasıyla yeterli; dosya küçük kalsın ki
      // yedek arşivi şişmesin.
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (shot == null) return null;
    return _persist(shot.path);
  }

  /// Geçici dosyayı kalıcı klasöre taşır ve yeni yolu döndürür.
  static Future<String> _persist(String sourcePath) async {
    final dir = await coversDirectory();
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final target = '${dir.path}/$name';
    await File(sourcePath).copy(target);
    return target;
  }

  /// Kapakların tutulduğu klasör (yoksa oluşturur).
  static Future<Directory> coversDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final covers = Directory('${dir.path}/covers');
    if (!await covers.exists()) await covers.create(recursive: true);
    return covers;
  }

  /// Verilen değer cihazdaki bir dosya mı, yoksa internet adresi mi?
  static bool isLocalPath(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return false;
    return !v.startsWith('http://') && !v.startsWith('https://');
  }
}
