// ignore: deprecated_member_use
import 'dart:html' as html;

/// Web : crée un lien <a download> et le clique pour télécharger le fichier.
/// (Le serveur renvoie Content-Disposition: attachment via ?download=1.)
Future<void> downloadUrl(String url, String filename) async {
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..target = "_blank"
    ..style.display = "none";
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

/// Web : même comportement que downloadUrl (le navigateur gère la sauvegarde).
Future<String?> downloadOnly(String url, String filename) async {
  await downloadUrl(url, filename);
  return null; // pas de système de fichiers local sur web
}

/// Web : pas d'ouverture de fichier local (le navigateur s'en charge).
Future<void> openLocalFile(String path) async {}
