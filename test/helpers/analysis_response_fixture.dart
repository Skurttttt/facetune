const validAnalysisResponse = <String, Object?>{
  'analysis': <String, Object?>{
    'id': '8ad50d8d-ff1c-4b1f-a376-58642328f463',
    'originalImagePath':
        'user/analyses/8ad50d8d-ff1c-4b1f-a376-58642328f463/original/image.jpg',
    'validation': <String, Object?>{
      'faceCount': 1,
      'lightingAcceptable': true,
      'sharpnessAcceptable': true,
      'faceVisible': true,
      'framingAcceptable': true,
    },
    'attributes': <String, Object?>{
      'faceShape': 'oval',
      'skinTone': 'medium',
      'undertone': 'warm',
      'eyeShape': 'almond',
      'lipShape': 'full',
      'hairColor': 'dark_brown',
      'eyeColor': 'brown',
    },
    'confidence': <String, Object?>{
      'faceShape': 0.91,
      'skinTone': 0.88,
      'undertone': 0.82,
      'eyeShape': 0.90,
      'lipShape': 0.87,
      'hairColor': 0.94,
      'eyeColor': 0.89,
    },
    'modelId': 'gemini-3.6-flash',
    'promptVersion': 'face_analysis_v1',
    'createdAt': '2026-08-11T00:00:00Z',
  },
};
