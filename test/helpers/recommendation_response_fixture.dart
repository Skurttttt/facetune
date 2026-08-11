const validRecommendationResponse = <String, Object?>{
  'recommendation': <String, Object?>{
    'id': 'ad5991d1-f554-4d23-a1de-aa8590b7f4ea',
    'analysisId': '8ad50d8d-ff1c-4b1f-a376-58642328f463',
    'style': 'soft_glam',
    'plan': <String, Object?>{
      'foundation': validRecommendationItem,
      'concealer': validRecommendationItem,
      'contour': validRecommendationItem,
      'highlight': validRecommendationItem,
      'blush': validRecommendationItem,
      'eyeshadow': validRecommendationItem,
      'eyebrow': validRecommendationItem,
      'eyeliner': validRecommendationItem,
      'lipstick': validRecommendationItem,
      'lipGloss': validRecommendationItem,
      'overallIntensity': 'soft',
    },
    'modelId': 'gemini-3.6-flash',
    'promptVersion': 'makeup_recommendation_v1',
    'createdAt': '2026-08-11T01:00:00Z',
  },
};

const validRecommendationItem = <String, Object?>{
  'name': 'Warm peach',
  'hex': '#E69A7A',
  'placement': 'Upper cheekbones',
  'technique': 'Blend upward with a soft brush',
  'finish': 'satin',
  'intensity': 'soft',
  'reasoning': 'Adds balanced warmth to the complexion.',
};
