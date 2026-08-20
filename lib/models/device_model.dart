enum DeviceConnectionStatus {
  available,
  using,
  busy,
  disconnected,
  unauthorized,
}

class DeviceDisplayInfo {
  final int width;
  final int height;
  final int rotation;
  final double density;
  final double fps;
  final String? streamUrl;

  const DeviceDisplayInfo({
    required this.width,
    required this.height,
    this.rotation = 0,
    this.density = 1.0,
    this.fps = 60.0,
    this.streamUrl,
  });

  bool get isLandscape => rotation == 90 || rotation == 270;

  DeviceDisplayInfo copyWith({
    int? width,
    int? height,
    int? rotation,
    double? density,
    double? fps,
    String? streamUrl,
  }) {
    return DeviceDisplayInfo(
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      density: density ?? this.density,
      fps: fps ?? this.fps,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }
}

class DeviceModel {
  final String serial;
  final String name;
  final String model;
  final String manufacturer;
  final String sdkVersion;
  final DeviceConnectionStatus status;
  final DeviceDisplayInfo display;
  final bool isPresent;
  final bool isReady;
  final String? owner;

  const DeviceModel({
    required this.serial,
    required this.name,
    required this.model,
    required this.manufacturer,
    required this.sdkVersion,
    required this.status,
    required this.display,
    this.isPresent = true,
    this.isReady = true,
    this.owner,
  });

  String get displayName => name.isNotEmpty ? name : model;

  DeviceModel copyWith({
    String? serial,
    String? name,
    String? model,
    String? manufacturer,
    String? sdkVersion,
    DeviceConnectionStatus? status,
    DeviceDisplayInfo? display,
    bool? isPresent,
    bool? isReady,
    String? owner,
  }) {
    return DeviceModel(
      serial: serial ?? this.serial,
      name: name ?? this.name,
      model: model ?? this.model,
      manufacturer: manufacturer ?? this.manufacturer,
      sdkVersion: sdkVersion ?? this.sdkVersion,
      status: status ?? this.status,
      display: display ?? this.display,
      isPresent: isPresent ?? this.isPresent,
      isReady: isReady ?? this.isReady,
      owner: owner ?? this.owner,
    );
  }
}
