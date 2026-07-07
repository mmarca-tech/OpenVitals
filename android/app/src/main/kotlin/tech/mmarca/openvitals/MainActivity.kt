package tech.mmarca.openvitals

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * The `health` plugin requires the host activity to be a
 * [FlutterFragmentActivity] (a `ComponentActivity`) so that Health Connect
 * permission requests can use `registerForActivityResult`. Extending
 * `FlutterActivity` would make Health Connect permission launches fail at
 * runtime.
 */
class MainActivity : FlutterFragmentActivity()
