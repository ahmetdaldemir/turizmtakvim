class GalleryPhoto {
  const GalleryPhoto({required this.id, required this.url});

  final int id;
  final String url;

  factory GalleryPhoto.fromJson(Map<String, dynamic> json) {
    return GalleryPhoto(
      id: (json['id'] as num).toInt(),
      url: json['url'] as String,
    );
  }
}

class GalleryAlbum {
  const GalleryAlbum({
    required this.id,
    required this.title,
    required this.photoCount,
    this.coverUrl,
    this.createdAt,
    this.photos = const [],
  });

  final int id;
  final String title;
  final int photoCount;
  final String? coverUrl;
  final DateTime? createdAt;
  final List<GalleryPhoto> photos;

  factory GalleryAlbum.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    final rawPhotos = json['photos'];
    return GalleryAlbum(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      photoCount: (json['photoCount'] as num?)?.toInt() ?? 0,
      coverUrl: json['coverUrl'] as String?,
      createdAt: created is String ? DateTime.tryParse(created) : null,
      photos: rawPhotos is List
          ? rawPhotos.map((item) => GalleryPhoto.fromJson(item as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}
