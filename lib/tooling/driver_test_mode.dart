/// Enabled only by the driver entry (lib/driver_main.dart) so automated
/// flutter_driver taps have time to reach hover-shown flyouts before they
/// auto-hide. Production builds keep the regular short hide delay.
bool kDriverTestMode = false;
