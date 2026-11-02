import 'dart:js_interop';

@JS('window.localStorage')
external BrowserStorage get _storage;

extension type BrowserStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
}

String? readLegacyPlan() => _storage.getItem('training-plan-v1'.toJS)?.toDart;
