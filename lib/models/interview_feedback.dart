import 'dart:convert';

class InterviewFeedback {
  final String interviewId;
  final int overallScore;
  final FeedbackSummary summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<QuestionEvaluation> questionEvaluations;

  const InterviewFeedback({
    required this.interviewId,
    required this.overallScore,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.questionEvaluations,
  });

  factory InterviewFeedback.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? resolveAnalysisResults(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is String) {
        try {
          final parsed = jsonDecode(v);
          if (parsed is Map<String, dynamic>) return parsed;
        } catch (_) {}
      }
      return null;
    }

    final summaryMap = (json['summary'] as Map<String, dynamic>?) ??
        resolveAnalysisResults(json['analysis_results'])?['summary'] as Map<String, dynamic>? ??
        const {};
    final rawEvaluations = (json['questionEvaluations'] as List<dynamic>?) ??
        (json['question_evaluations'] as List<dynamic>?) ??
        const [];
    final evaluations = rawEvaluations
        .whereType<Map<String, dynamic>>()
        .map(QuestionEvaluation.fromJson)
        .toList();

    return InterviewFeedback(
      interviewId: (json['interviewId'] ?? json['id'] ?? '').toString(),
      overallScore: _toInt(json['overallScore'] ?? json['overall_score']),
      summary: FeedbackSummary.fromJson(summaryMap),
      strengths: _toStringList(
        json['strengths'] ?? json['analysis_results']?['strengths'],
      ),
      improvements: _toStringList(
        json['improvements'] ?? json['analysis_results']?['improvements'],
      ),
      questionEvaluations: evaluations,
    );
  }
}

class FeedbackSummary {
  final int voiceTone;
  final int facialExpression;
  final int contentQuality;

  const FeedbackSummary({
    required this.voiceTone,
    required this.facialExpression,
    required this.contentQuality,
  });

  factory FeedbackSummary.fromJson(Map<String, dynamic> json) {
    return FeedbackSummary(
      voiceTone: _toInt(json['voiceTone'] ?? json['voice_tone']),
      facialExpression:
          _toInt(json['facialExpression'] ?? json['facial_expression']),
      contentQuality: _toInt(json['contentQuality'] ?? json['content_quality']),
    );
  }
}

class QuestionEvaluation {
  final int questionNumber;
  final String question;
  final String answer;
  final int score;
  final String feedback;

  const QuestionEvaluation({
    required this.questionNumber,
    required this.question,
    required this.answer,
    required this.score,
    required this.feedback,
  });

  factory QuestionEvaluation.fromJson(Map<String, dynamic> json) {
    String _extractFeedback(dynamic fb) {
      if (fb is Map<String, dynamic>) {
        return fb['suggestions'] ??
            fb['suggestion'] ??
            fb['comment'] ??
            fb['text'] ??
            '';
      }
      return fb?.toString() ?? '';
    }

    return QuestionEvaluation(
      questionNumber: _toInt(json['questionNumber'] ?? json['question_number']),
      question: (json['question'] ?? json['question_text'] ?? '').toString(),
      answer: (json['answer'] ?? json['answer_text'] ?? '').toString(),
      score: _toInt(json['score']),
      feedback: _extractFeedback(json['feedback']),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _toStringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
}
