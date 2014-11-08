// Copyright (c) 2014, the vsync project authors. Please see the AUTHORS file for
// details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of vdom;

/// Virtual Dom Element
class Element extends Node {
  /// [Element] tag name
  final String tag;

  /// [Element] attributes
  Map<String, String> attributes;

  /// [Element] styles
  Map<String, String> styles;

  /// Element classes
  List<String> classes;

  /// Element children
  List<Node> children;

  /// Create a new [Element]
  Element(Object key, this.tag, this.children,
          {this.attributes: null,
           this.classes: null,
           this.styles: null}) : super(key) {
    assert(children != null);
  }

  void sync(Element other, Context context) {
    other.ref = ref;
    html.Element r = ref;
    if (attributes != null || other.attributes != null) {
      syncMap(attributes, other.attributes, r.attributes);
    }
    if (styles != null || other.styles != null) {
      syncStyle(styles, other.styles, r.style);
    }
    if (classes != null || other.classes != null) {
      syncSet(classes, other.classes, r.classes);
    }
    syncChildren(children, other.children, r, context);
  }

  /// Render [Element] and return [html.Element]
  html.Element render(Context context) {
    ref = html.document.createElement(tag);
    mount(ref, context);
    return ref;
  }

  /// Inject into container
  void inject(html.Element container, Context context) {
    var element = html.document.createElement(tag);
    container.append(element);
    mount(element, context);
  }

  /// Inject into container before [nextRef] node
  void injectBefore(html.Element container, html.Node nextRef,
                    Context context) {
    var element = html.document.createElement(tag);
    container.insertBefore(element, nextRef);
    mount(element, context);
  }

  /// Mount on top of existing element
  void mount(html.Element element, Context context) {
    ref = element;
    if (context.isAttached) {
      attached();
    }
    if (attributes != null) {
      attributes.forEach((key, value) {
        element.setAttribute(key, value);
      });
    }
    if (styles != null) {
      styles.forEach((key, value) {
        element.style.setProperty(key, value);
      });
    }
    if (classes != null) {
      element.classes.addAll(classes);
    }

    for (var i = 0; i < children.length; i++) {
      children[i].inject(element, context);
    }
  }

  void propagateAttached() {
    attached();
    for (var i = 0; i < children.length; i++) {
      children[i].propagateAttached();
    }
  }

  void propagateDetached() {
    detached();
    for (var i = 0; i < children.length; i++) {
      children[i].propagateDetached();
    }
  }

  String toString() => '<$tag key="$key">${children.join()}</$tag>';
}

void syncChildren(List<Node> a, List<Node> b, html.Element parent, Context context) {
  if (a.isNotEmpty) {
    if (b.isEmpty) {
      // when [b] is empty, it means that all childrens from list [a] were
      // removed
      for (var i = 0; i < a.length; i++) {
        a[i].dispose(context);
      }
    } else {
      if (a.length == 1 && b.length == 1) {
        // fast path when [a] and [b] have just 1 child
        //
        // if both lists have child with the same key, then just diff them,
        // otherwise return patch with [a] child removed and [b] child inserted
        final aNode = a.first;
        final bNode = b.first;

        if (aNode.key == bNode.key) {
          var modified = aNode.sync(bNode, context);
        } else {
          aNode.dispose(context);
          bNode.inject(parent, context);
        }
      } else if (a.length == 1) {
        // fast path when [a] have 1 child
        final aNode = a.first;

        // [a] child position
        // if it is -1, then the child is removed
        var unchangedPosition = -1;

        for (var i = 0; i < b.length; i++) {
          final bNode = b[i];
          if (aNode.key == bNode.key) {
            unchangedPosition = i;
            break;
          } else {
            bNode.injectBefore(parent, aNode.ref, context);
          }
        }

        if (unchangedPosition != -1) {
          for (var i = unchangedPosition + 1; i < b.length; i++) {
            final n = b[i];
            n.inject(parent, context);
          }
          aNode.sync(b[unchangedPosition], context);
        } else {
          aNode.dispose(context);
        }
      } else if (b.length == 1) {
        // fast path when [b] have 1 child
        final bNode = b.first;

        // [a] child position
        // if it is -1, then the child is inserted
        var unchangedPosition = -1;

        for (var i = 0; i < a.length; i++) {
          final aNode = a[i];
          if (aNode.key == bNode.key) {
            unchangedPosition = i;
            break;
          } else {
            aNode.dispose(context);
          }
        }

        if (unchangedPosition != -1) {
          for (var i = unchangedPosition + 1; i < a.length; i++) {
            a[i].dispose(context);
          }
          a[unchangedPosition].sync(bNode, context);
        } else {
          bNode.inject(parent, context);
        }
      } else {
        // both [a] and [b] have more than 1 child, so we should handle
        // more complex situations with inserting/removing and repositioning
        // childrens
        return _syncChildren2(a, b, parent, context);
      }
    }
  } else if (b.length > 0) {
    // all childrens from list [b] were inserted
    for (var i = 0; i < b.length; i++) {
      final n = b[i];
      n.inject(parent, context);
    }
  }
}

void _syncChildren2(List<Node> a, List<Node> b, html.Element parent, Context context) {
  var aLength = a.length;
  var bLength = b.length;

  final minLength = aLength < bLength ? aLength : bLength;

  var start = 0;

  while(start < minLength) {
    final aNode = a[start];
    final bNode = b[start];
    if (aNode.key != bNode.key) {
      break;
    }
    aNode.sync(bNode, context);
    start++;
  }

  if (start == bLength) {
    if (start != aLength) {
      for (var i = start; i < a.length; i++) {
        a[i].dispose(context);
      }
    }
  } else if (start == aLength) {
    for (var i = start; i < b.length; i++) {
      final n = b[i];
      n.inject(parent, context);
    }
  } else {
    var aEnd = a.length - 1;
    var bEnd = b.length - 1;
    while (aEnd >= start && bEnd >= start) {
      final aNode = a[aEnd];
      final bNode = b[bEnd];

      if (aNode.key != bNode.key) {
        break;
      }
      aNode.sync(bNode, context);
      aEnd--;
      bEnd--;
    }
    aEnd++;
    bEnd++;

    if (aEnd == start) {
      assert(bEnd != start);
      final aEndRef = a[aEnd].ref;
      for (var i = start; i < bEnd; i++) {
        final n = b[i];
        n.injectBefore(parent, aEndRef, context);
      }
    } else if (bEnd == start) {
      for (var i = start; i < aEnd; i++) {
        a[i].dispose(context);
      }
    } else {
      aLength = aEnd - start;
      bLength = bEnd - start;

      final sources = new List<int>.filled(bLength, -1);

      var moved = false;
      var removeOffset = 0;

      // when both lists are small, the join operation is much faster with simple
      // MxN list search instead of hashmap join
      if (aLength * bLength <= 16) {
        var lastTarget = 0;

        for (var i = 0; i < aLength; i++) {
          final iOff = i + start;
          final aNode = a[iOff];
          var removed = true;

          for (var j = 0; j < bLength; j++) {
            final jOff = j + start;
            final bNode = b[jOff];
            if (aNode.key == bNode.key) {
              sources[j] = iOff;

              if (lastTarget > j) {
                moved = true;
              } else {
                lastTarget = j;
              }

              aNode.sync(bNode, context);

              removed = false;
              break;
            }
          }

          if (removed) {
            aNode.dispose(context);
            removeOffset++;
          }
        }

      } else {
        final keyIndex = new HashMap<Object, int>();
        var lastTarget = 0;

        for (var i = 0; i < bLength; i++) {
          final node = b[i + start];
          keyIndex[node.key] = i;
        }

        for (var i = 0; i < aLength; i++) {
          final iOff = i + start;
          final aNode = a[iOff];
          final j = keyIndex[aNode.key];
          if (j != null) {
            final jOff = j + start;
            final bNode = b[jOff];
            sources[j] = iOff;

            if (lastTarget > j) {
              moved = true;
            } else {
              lastTarget = j;
            }

            aNode.sync(bNode, context);
          } else {
            aNode.dispose(context);
            removeOffset++;
          }
        }
      }

      if (moved) {
        final seq = _lis(sources);
        var j = seq.length - 1;

        for (var i = bLength - 1; i >= 0; i--) {
          if (sources[i] == -1) {
            final pos = i + start;
            final node = b[pos];
            final nextPos = pos + 1;
            final next = nextPos < b.length ? b[nextPos].ref : null;
            node.injectBefore(parent, next, context);
          } else {
            if (j < 0 || i != seq[j]) {
              final pos = i + start;
              final node = a[sources[i]];
              final nextPos = pos + 1;
              final next = nextPos < b.length ? b[nextPos].ref : null;
              parent.insertBefore(node.ref, next);
            } else {
              j--;
            }
          }
        }

      } else if (aLength - removeOffset != bLength) {
        for (var i = bLength - 1; i >= 0; i--) {
          if (sources[i] == -1) {
            final pos = i + start;
            final node = b[pos];
            final nextPos = pos + 1;
            final next = nextPos < b.length ? b[nextPos].ref : null;
            node.injectBefore(parent, next, context);
          }
        }
      }
    }
  }
}

/// Algorithm that finds longest increasing subsequence.
List<int> _lis(List<int> a) {
  final p = new List<int>.from(a);
  final result = new List<int>();

  result.add(0);

  for (var i = 0; i < a.length; i++) {
    if (a[i] == -1) {
      continue;
    }
    if (a[result.last] < a[i]) {
      p[i] = result.last;
      result.add(i);
      continue;
    }

    var u = 0;
    var v = result.length - 1;
    while (u < v) {
      int c = (u + v) ~/ 2;

      if (a[result[c]] < a[i]) {
        u = c + 1;
      } else {
        v = c;
      }
    }

    if (a[i] < a[result[u]]) {
      if (u > 0) {
        p[i] = result[u - 1];
      }

      result[u] = i;
    }
  }
  var u = result.length;
  var v = result.last;

  while (u-- > 0) {
    result[u] = v;
    v = p[v];
  }

  return result;
}
