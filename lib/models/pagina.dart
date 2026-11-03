class Pagina<T> {
  final List<T> itens;
  final int total;
  final int offset;
  final bool temMais;

  const Pagina({
    required this.itens,
    required this.total,
    required this.offset,
    required this.temMais,
  });

  factory Pagina.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonItem,
  ) {
    return Pagina(
      itens: (json['items'] as List).map((i) => fromJsonItem(i as Map<String, dynamic>)).toList(),
      total: (json['total'] as num).toInt(),
      offset: (json['offset'] as num).toInt(),
      temMais: json['has_more'] as bool,
    );
  }
}
