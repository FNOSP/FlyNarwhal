/// Builds and parses the FNWB2 white-box build-proof message.
///
/// The canonical message binds the white-box CMAC to the exact FNK2 request
/// signature: url/ts/nonce/instanceId/method are the values already covered
/// by the Fnauth HMAC, and fnauthSig is that HMAC's output. The Go signer
/// library and the server-side verifier must reproduce this string verbatim.
class FlyNarwhalWbHelper {
  const FlyNarwhalWbHelper._();

  static String buildFnwbMessage({
    required String method,
    required String url,
    required String ts,
    required String nonce,
    required String dataJsonMd5,
    required String instanceId,
    required String fnauthSig,
  }) {
    return [
      'FNWB2',
      method.toUpperCase(),
      url,
      ts,
      nonce,
      dataJsonMd5,
      instanceId,
      fnauthSig,
    ].join('_');
  }

  /// Splits a Fnauth header value into its parts (keyid/ts/nonce/sig), the
  /// same way generateSignx parses an Authx header.
  static Map<String, String> parseFnauth(String fnauth) {
    return Uri.splitQueryString(fnauth);
  }
}