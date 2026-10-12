/// 行动牌图片仅供展示；身份、消耗及指示仍由GameConstants/GameState管理。
abstract final class ActionCardArtwork {
  static const paperPath = 'assets/storybook/action_paper.png';
  static const nightPaperPath = 'assets/storybook/action_night.png';
  static const paths = <int, String>{
    1: 'assets/action_cards/action01.png',
    2: 'assets/action_cards/action02.png',
    3: 'assets/action_cards/action03.png',
    4: 'assets/action_cards/action04.png',
    5: 'assets/action_cards/action05.png',
  };
}
