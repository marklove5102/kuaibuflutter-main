class TTSEngine {
  final String name;
  final String label;
  final bool isSystem;

  TTSEngine({
    required this.name,
    required this.label,
    this.isSystem = true,
  });

  factory TTSEngine.fromJson(Map<String, dynamic> json) {
    var isSystemValue = json['isSystem'];
    bool isSystemBool;
    if (isSystemValue is bool) {
      isSystemBool = isSystemValue;
    } else if (isSystemValue is String) {
      isSystemBool = isSystemValue.toLowerCase() == 'true';
    } else {
      isSystemBool = true;
    }
    
    return TTSEngine(
      name: json['name'] ?? '',
      label: json['label'] ?? '',
      isSystem: isSystemBool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'label': label,
      'isSystem': isSystem,
    };
  }

  @override
  String toString() {
    return 'TTSEngine{name: $name, label: $label, isSystem: $isSystem}';
  }
}

class SelectItem<T> {
  final String title;
  final T value;

  SelectItem(this.title, this.value);

  factory SelectItem.fromJson(Map<String, dynamic> json) {
    return SelectItem(
      json['title'] ?? '',
      json['value'] as T,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'value': value,
    };
  }
}
