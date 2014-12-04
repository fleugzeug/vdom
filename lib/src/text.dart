// Copyright (c) 2014, the VDom project authors. Please see the AUTHORS file for
// details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of vdom;

/// [Text] Node
class Text extends Node<html.Text> {
  /// [Text] content
  String data;

  Text(this.data, {Object key}) : super(key);

  void create(Context context) {
    ref = new html.Text(data);
  }

  void update(Text other, Context context) {
    super.update(other, context);
    if (data != other.data) {
      ref.data = other.data;
    }
  }

  String toString() => '$data';
}
