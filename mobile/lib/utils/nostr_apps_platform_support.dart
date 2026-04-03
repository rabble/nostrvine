import 'package:flutter/foundation.dart';

bool supportsNostrAppsSandbox({required bool isWeb}) => !isWeb;

bool get nostrAppsSandboxSupported => supportsNostrAppsSandbox(isWeb: kIsWeb);
