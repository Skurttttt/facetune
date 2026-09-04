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

/// A plan stored before education existed.
///
/// This is deliberately the same object as [validRecommendationResponse],
/// named for the property the historical-compatibility tests rely on. Ten test
/// files already build on the education-free fixture, so every one of them is a
/// standing check that a `makeup_recommendation_v2` row still decodes.
const legacyRecommendationResponse = validRecommendationResponse;

const validRecommendationEducation = <String, Object?>{
  'features': 'Your warm undertone and medium depth guided this peach choice.',
  'effect': 'A soft satin peach adds warmth without flattening the cheek.',
  'style': 'It keeps the soft glam register bright rather than heavy.',
};

const educatedRecommendationItem = <String, Object?>{
  'name': 'Warm peach',
  'hex': '#E69A7A',
  'placement': 'Upper cheekbones',
  'technique': 'Blend upward with a soft brush',
  'finish': 'satin',
  'intensity': 'soft',
  'reasoning': 'Adds balanced warmth to the complexion.',
  'education': validRecommendationEducation,
};

/// A plan produced under `makeup_recommendation_v3`, carrying education.
const educatedRecommendationResponse = <String, Object?>{
  'recommendation': <String, Object?>{
    'id': 'ad5991d1-f554-4d23-a1de-aa8590b7f4ea',
    'analysisId': '8ad50d8d-ff1c-4b1f-a376-58642328f463',
    'style': 'soft_glam',
    'plan': <String, Object?>{
      'foundation': educatedRecommendationItem,
      'concealer': educatedRecommendationItem,
      'contour': educatedRecommendationItem,
      'highlight': educatedRecommendationItem,
      'blush': educatedRecommendationItem,
      'eyeshadow': educatedRecommendationItem,
      'eyebrow': educatedRecommendationItem,
      'eyeliner': educatedRecommendationItem,
      'lipstick': educatedRecommendationItem,
      'lipGloss': educatedRecommendationItem,
      'overallIntensity': 'soft',
    },
    'modelId': 'gemini-3.6-flash',
    'promptVersion': 'makeup_recommendation_v3',
    'createdAt': '2026-09-04T01:00:00Z',
  },
};
