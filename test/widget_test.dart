// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:ble_app/bi_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ble_app/main.dart';

void main() {
  test('insert1', () {
    final BiMap<String, String> biMap = new BiMap();

    biMap["a"] = "b";

    expect(biMap["a"], "b");
    expect(biMap.inverse("b"), "a");
  });

  test('insert2', () {
    final BiMap<String, String> biMap = new BiMap();

    biMap["a"] = "b";
    biMap["a"] = "c";

    expect(biMap["a"], "c");
    expect(biMap.inverse("b"), null);
    expect(biMap.inverse("c"), "a");
  });

  test('insert1', () {
    final BiMap<String, String> biMap = new BiMap();

    biMap["a"] = "b";

    expect(biMap["a"], "b");
    expect(biMap.inverse("b"), "a");

    biMap.remove("a");

    expect(biMap["a"], null);
    expect(biMap.inverse("b"), null);
  });



}
