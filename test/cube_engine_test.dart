import 'package:flutter_test/flutter_test.dart';
import 'package:twistycube/engine/cube_engine.dart';

/// Validates the derived face-turn permutations against real cube-group
/// properties for every supported size. These mirror the checks run in
/// Python during development (see the build notes).
List<int> _apply(List<int> state, List<int> perm) =>
    [for (int j = 0; j < state.length; j++) state[perm[j]]];

List<int> _compose(List<int> p, List<int> q) =>
    [for (int j = 0; j < p.length; j++) p[q[j]]];

List<int> _inverse(List<int> p) {
  final inv = List<int>.filled(p.length, 0);
  for (int j = 0; j < p.length; j++) {
    inv[p[j]] = j;
  }
  return inv;
}

int _order(List<int> p) {
  final n = p.length;
  var cur = List<int>.generate(n, (i) => i);
  var k = 0;
  while (true) {
    cur = _compose(cur, p);
    k++;
    var ident = true;
    for (int i = 0; i < n; i++) {
      if (cur[i] != i) {
        ident = false;
        break;
      }
    }
    if (ident) return k;
    assert(k < 200, 'permutation order suspiciously large');
  }
}

void main() {
  for (final n in [2, 3, 4]) {
    group('cube size $n', () {
      test('every face turn has order 4', () {
        final perms = turnPermutations(n);
        for (final p in perms) {
          expect(_order(p), 4);
        }
      });

      test('inverse move sequences re-solve the cube', () {
        final perms = turnPermutations(n);
        final inv = [for (final p in perms) _inverse(p)];
        var state = [
          for (int i = 0; i < 6 * n * n; i++) i ~/ (n * n)
        ];
        // Deterministic scramble: faces cycle, alternating direction.
        final seq = [
          for (int k = 0; k < 40; k++) (k % 6, k % 2 == 0)
        ];
        for (final (f, cw) in seq) {
          state = _apply(state, cw ? perms[f] : inv[f]);
        }
        expect(isSolvedState(state, n), isFalse);
        for (final (f, cw) in seq.reversed) {
          state = _apply(state, cw ? inv[f] : perms[f]);
        }
        expect(isSolvedState(state, n), isTrue);
      });

      test('sexy move (R U R\' U\') has order 6', () {
        final perms = turnPermutations(n);
        final inv = [for (final p in perms) _inverse(p)];
        final sexy = _compose(
            _compose(_compose(perms[1], perms[0]), inv[1]), inv[0]);
        expect(_order(sexy), 6);
      });

      test('solved detection is exact', () {
        final solved = [
          for (int i = 0; i < 6 * n * n; i++) i ~/ (n * n)
        ];
        expect(isSolvedState(solved, n), isTrue);
        final almost = List<int>.of(solved);
        almost[0] = 1;
        expect(isSolvedState(almost, n), isFalse);
      });

      test('sticker coordinates are unique per cube', () {
        final seen = <String>{};
        for (int i = 0; i < 6 * n * n; i++) {
          seen.add(stickerCoords(i, n).join(','));
        }
        expect(seen.length, 6 * n * n);
      });
    });
  }

  test('tier table matches the design', () {
    expect(cubeTiers.length, 3);
    expect(cubeTiers[0].size, 2);
    expect(cubeTiers[1].size, 3);
    expect(cubeTiers[2].size, 4);
    for (final t in cubeTiers) {
      expect(t.scrambleDepth, greaterThan(0));
      expect(t.timeLimitSecs, greaterThan(t.parSecs));
    }
  });
}
