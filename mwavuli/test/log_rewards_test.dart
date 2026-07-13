import 'package:flutter_test/flutter_test.dart';
import 'package:mwavuli/core/id/identification_service.dart';

void main() {
  test('LogRewards.fromApi parses rewards payload', () {
    final r = LogRewards.fromApi({
      'pointsEarned': 10,
      'totalPoints': 120,
      'level': 3,
      'levelName': 'Sapling',
    });
    expect(r.pointsEarned, 10);
    expect(r.totalPoints, 120);
    expect(r.level, 3);
    expect(r.levelName, 'Sapling');
  });

  test('LogRewards.fromApi falls back when rewards missing', () {
    final r = LogRewards.fromApi(null);
    expect(r.pointsEarned, 10);
    expect(r.level, 1);
    expect(r.levelName, 'Seedling');
  });
}
