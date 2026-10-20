import 'package:flutter/material.dart';

/// A companion's charged skill. The first two act on the board instantly;
/// the rest arm the next shot.
enum DinoAbility { stomp, lift, pierce, bomb, rainbow }

extension DinoAbilityInfo on DinoAbility {
  String get title => switch (this) {
    DinoAbility.stomp => 'Dậm đất',
    DinoAbility.lift => 'Ăn ngọn',
    DinoAbility.pierce => 'Húc xuyên',
    DinoAbility.bomb => 'Gai nổ',
    DinoAbility.rainbow => 'Trứng cầu vồng',
  };

  String get description => switch (this) {
    DinoAbility.stomp => 'Dậm mạnh xuống đất, phá sạch 2 hàng trứng thấp nhất.',
    DinoAbility.lift => 'Ăn hàng trứng trên cùng như ăn ngọn cây, kéo cả bàn trứng lùi lên 1 hàng.',
    DinoAbility.pierce => 'Quả trứng kế tiếp bay xuyên thủng mọi quả trứng trên đường đi.',
    DinoAbility.bomb => 'Quả trứng kế tiếp phát nổ khi chạm, phá mọi trứng trong bán kính 2 ô.',
    DinoAbility.rainbow => 'Quả trứng kế tiếp tự đổi sang màu tạo được chuỗi dài nhất tại chỗ nó đáp.',
  };

  bool get armsNextShot => switch (this) {
    DinoAbility.stomp || DinoAbility.lift => false,
    _ => true,
  };
}

enum DinoSpecies { trex, triceratops, stegosaurus, pteranodon, brachiosaurus }

class DinoInfo {
  final String nameVi;
  final String scientificName;
  final String initials;
  final String period;
  final String size;
  final String weight;
  final String diet;
  final String foundIn;
  final List<String> facts;
  final DinoAbility ability;
  final Color color;

  const DinoInfo({
    required this.nameVi,
    required this.scientificName,
    required this.initials,
    required this.period,
    required this.size,
    required this.weight,
    required this.diet,
    required this.foundIn,
    required this.facts,
    required this.ability,
    required this.color,
  });
}

extension DinoSpeciesInfo on DinoSpecies {
  DinoInfo get info => _dinoInfo[this]!;

  /// Portrait art under assets/images/. Missing files fall back to a drawn
  /// placeholder token, so the game runs before the art exists.
  String get portraitFile => 'dino_$name.png';
}

const Map<DinoSpecies, DinoInfo> _dinoInfo = {
  DinoSpecies.trex: DinoInfo(
    nameVi: 'Khủng long bạo chúa',
    scientificName: 'Tyrannosaurus rex',
    initials: 'T',
    period: 'Cuối kỷ Phấn Trắng (khoảng 68–66 triệu năm trước)',
    size: 'Dài khoảng 12 m',
    weight: 'Nặng khoảng 8 tấn',
    diet: 'Ăn thịt',
    foundIn: 'Bắc Mỹ (Mỹ, Canada)',
    facts: [
      'Có lực cắn thuộc hàng mạnh nhất trong các loài động vật trên cạn từng được biết đến.',
      'Hai chi trước rất ngắn, mỗi bên chỉ có 2 ngón.',
      'Chiếc răng lớn nhất dài khoảng 30 cm nếu tính cả chân răng.',
    ],
    ability: DinoAbility.stomp,
    color: Color(0xFFE53935),
  ),
  DinoSpecies.triceratops: DinoInfo(
    nameVi: 'Khủng long ba sừng',
    scientificName: 'Triceratops horridus',
    initials: 'Tr',
    period: 'Cuối kỷ Phấn Trắng (khoảng 68–66 triệu năm trước)',
    size: 'Dài khoảng 8–9 m',
    weight: 'Nặng khoảng 6–12 tấn',
    diet: 'Ăn thực vật',
    foundIn: 'Bắc Mỹ',
    facts: [
      'Tên gọi có nghĩa là "mặt có ba sừng".',
      'Diềm xương lớn sau đầu có thể giúp tự vệ và nhận ra đồng loại.',
      'Sống cùng thời và cùng khu vực với khủng long bạo chúa.',
    ],
    ability: DinoAbility.pierce,
    color: Color(0xFF1E88E5),
  ),
  DinoSpecies.stegosaurus: DinoInfo(
    nameVi: 'Khủng long phiến lưng',
    scientificName: 'Stegosaurus stenops',
    initials: 'St',
    period: 'Cuối kỷ Jura (khoảng 155–150 triệu năm trước)',
    size: 'Dài khoảng 9 m',
    weight: 'Nặng khoảng 5 tấn',
    diet: 'Ăn thực vật',
    foundIn: 'Bắc Mỹ và Bồ Đào Nha',
    facts: [
      'Tên gọi có nghĩa là "thằn lằn có mái" vì các phiến xương lớn trên lưng.',
      'Đuôi có 4 gai nhọn dài để chống lại kẻ săn mồi.',
      'Sống cách khủng long bạo chúa về thời gian còn xa hơn khoảng cách từ khủng long bạo chúa đến con người ngày nay.',
    ],
    ability: DinoAbility.bomb,
    color: Color(0xFFFB8C00),
  ),
  DinoSpecies.pteranodon: DinoInfo(
    nameVi: 'Dực long',
    scientificName: 'Pteranodon longiceps',
    initials: 'Pt',
    period: 'Cuối kỷ Phấn Trắng (khoảng 86–84 triệu năm trước)',
    size: 'Sải cánh có thể tới khoảng 7 m',
    weight: 'Nặng khoảng 20–50 kg',
    diet: 'Ăn cá',
    foundIn: 'Bắc Mỹ (bang Kansas, Mỹ)',
    facts: [
      'Thực ra dực long không phải khủng long, mà là một loài bò sát bay sống cùng thời.',
      'Miệng không có răng, có lẽ bắt cá giống các loài chim biển ngày nay.',
      'Chiếc mào dài phía sau đầu là đặc điểm nổi bật nhất.',
    ],
    ability: DinoAbility.rainbow,
    color: Color(0xFF8E24AA),
  ),
  DinoSpecies.brachiosaurus: DinoInfo(
    nameVi: 'Khủng long cổ dài',
    scientificName: 'Brachiosaurus altithorax',
    initials: 'Br',
    period: 'Cuối kỷ Jura (khoảng 154–153 triệu năm trước)',
    size: 'Dài khoảng 18–22 m',
    weight: 'Nặng khoảng 30–50 tấn',
    diet: 'Ăn thực vật (lá trên ngọn cây cao)',
    foundIn: 'Bắc Mỹ',
    facts: [
      'Tên gọi có nghĩa là "thằn lằn tay" vì chân trước dài hơn chân sau.',
      'Có thể vươn đầu cao khoảng 9–13 m, ngang một tòa nhà 3–4 tầng.',
      'Là một trong những động vật lớn nhất từng đi lại trên cạn.',
    ],
    ability: DinoAbility.lift,
    color: Color(0xFF43A047),
  ),
};
