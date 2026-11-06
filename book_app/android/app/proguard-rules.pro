# R8 / ProGuard kuralları — yalnızca release derlemesinde geçerli.

# ML Kit metin tanıma: eklenti bütün dilleri (Çince, Japonca, Korece,
# Devanagari) referans ediyor ama biz yalnızca Latin paketini bağımlılık
# olarak alıyoruz. Dolayısıyla bu sınıflar APK'da hiç yok ve R8 haklı olarak
# "eksik sınıf" diyor. Kullanmadığımız için uyarıları susturuyoruz; aksi
# halde release derlemesi hiç tamamlanmıyor.
#
# Başka bir alfabe için OCR eklemek istersek, ilgili paketi pubspec'e
# eklemek ve buradaki satırı kaldırmak gerekir.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
