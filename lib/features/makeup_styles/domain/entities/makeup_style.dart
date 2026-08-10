enum MakeupStyleId {
  natural,
  everyday,
  office,
  softGlam,
  fullGlam,
  bridal,
  korean,
  cleanGirl,
  party,
  dateNight,
  noMakeupMakeup,
  oldMoney,
}

class MakeupStyle {
  const MakeupStyle({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
  });

  final MakeupStyleId id;
  final String code;
  final String name;
  final String description;
}
