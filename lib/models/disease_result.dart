class DiseaseResult {
  final String diseaseName;
  final String description;
  final String treatment;
  final double confidence;

  DiseaseResult({
    required this.diseaseName,
    required this.description,
    required this.treatment,
    required this.confidence,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    return DiseaseResult(
      diseaseName: json['diseaseName'] ?? 'Unknown',
      description: json['description'] ?? 'No description available',
      treatment: json['treatment'] ?? 'No treatment information available',
      confidence: json['confidence']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diseaseName': diseaseName,
      'description': description,
      'treatment': treatment,
      'confidence': confidence,
    };
  }
}