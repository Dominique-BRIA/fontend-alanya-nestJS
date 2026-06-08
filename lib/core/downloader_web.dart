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
