/// Where everything bundled lives. The files are the React Native demo's own.
const avatarKeys = ['a01', 'a02', 'a03', 'a04', 'a05', 'a06', 'a07', 'a08', 'a09', 'a10', 'a11', 'a12', 'a13', 'a14', 'a15', 'a16'];
const themeKeys = ['royal', 'neon', 'galaxy', 'city', 'sunset', 'ocean'];
const _giftIcons = {'heart', 'rose', 'ring', 'rocket', 'crown', 'wolf', 'lion'};

String avatarAsset(String? key) => 'assets/avatars/${avatarKeys.contains(key) ? key : 'a01'}.png';
String frameAsset(String frame) => 'assets/art/frame-$frame.png';
String crestAsset(String frame) => 'assets/art/crest-$frame.png';
String coverAsset(String key) => 'assets/covers/${themeKeys.contains(key) ? key : 'royal'}.jpg';
String giftIconAsset(String key) => 'assets/gifts/${_giftIcons.contains(key) ? key : 'heart'}.png';

class Art {
  const Art._();

  static const throne = 'assets/art/throne.png';
  static const crown = 'assets/art/hero-crown.png';
  static const mark = 'assets/brand/mark.png';
}
