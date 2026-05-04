import 'package:flutter/material.dart';

@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  final TextStyle mediumXs;
  final TextStyle mediumSm;
  final TextStyle mediumBase;
  final TextStyle medium3xl;
  final TextStyle semibold2xs;
  final TextStyle semiboldXs;
  final TextStyle semiboldSm;
  final TextStyle semiboldBase;
  final TextStyle semiboldLg;
  final TextStyle semibold2xl;
  final TextStyle boldXs;
  final TextStyle boldSm;
  final TextStyle boldBase;
  final TextStyle boldLg;
  final TextStyle boldXl;
  final TextStyle bold4xl;

  const AppTextTheme({
    required this.mediumXs,
    required this.mediumSm,
    required this.mediumBase,
    required this.medium3xl,
    required this.semibold2xs,
    required this.semiboldXs,
    required this.semiboldSm,
    required this.semiboldBase,
    required this.semiboldLg,
    required this.semibold2xl,
    required this.boldXs,
    required this.boldSm,
    required this.boldBase,
    required this.boldLg,
    required this.boldXl,
    required this.bold4xl,
  });

  const AppTextTheme.fallback()
    : this(
        mediumXs: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
          height: 1.58,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        mediumSm: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
          height: 1,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        mediumBase: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
          height: 1.13,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        medium3xl: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
          height: 1.2,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semibold2xs: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          height: 1.2,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semiboldXs: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          height: 1.58,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semiboldSm: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
          height: 1,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semiboldBase: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          fontFamily: 'Poppins',
          height: 1.13,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semiboldLg: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          fontFamily: 'Poppins',
          height: 1.2,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        semibold2xl: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          fontFamily: 'Poppins',
          height: 1.25,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        boldXs: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          height: 1.17,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        boldSm: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          height: 1,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        boldBase: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          height: 1.13,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        boldLg: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          height: 1.2,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        boldXl: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          height: 1.17,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
        bold4xl: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          height: 1.17,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
        ),
      );

  @override
  AppTextTheme copyWith({
    TextStyle? mediumXs,
    TextStyle? mediumSm,
    TextStyle? mediumBase,
    TextStyle? medium3xl,
    TextStyle? semibold2xs,
    TextStyle? semiboldXs,
    TextStyle? semiboldSm,
    TextStyle? semiboldBase,
    TextStyle? semiboldLg,
    TextStyle? semibold2xl,
    TextStyle? boldXs,
    TextStyle? boldSm,
    TextStyle? boldBase,
    TextStyle? boldLg,
    TextStyle? boldXl,
    TextStyle? bold4xl,
  }) {
    return AppTextTheme(
      mediumXs: mediumXs ?? this.mediumXs,
      mediumSm: mediumSm ?? this.mediumSm,
      mediumBase: mediumBase ?? this.mediumBase,
      medium3xl: medium3xl ?? this.medium3xl,
      semibold2xs: semibold2xs ?? this.semibold2xs,
      semiboldXs: semiboldXs ?? this.semiboldXs,
      semiboldSm: semiboldSm ?? this.semiboldSm,
      semiboldBase: semiboldBase ?? this.semiboldBase,
      semiboldLg: semiboldLg ?? this.semiboldLg,
      semibold2xl: semibold2xl ?? this.semibold2xl,
      boldXs: boldXs ?? this.boldXs,
      boldSm: boldSm ?? this.boldSm,
      boldBase: boldBase ?? this.boldBase,
      boldLg: boldLg ?? this.boldLg,
      boldXl: boldXl ?? this.boldXl,
      bold4xl: bold4xl ?? this.bold4xl,
    );
  }

  @override
  AppTextTheme lerp(AppTextTheme? other, double t) {
    if (other is! AppTextTheme) return this;
    return AppTextTheme(
      mediumXs: TextStyle.lerp(mediumXs, other.mediumXs, t) ?? mediumXs,
      mediumSm: TextStyle.lerp(mediumSm, other.mediumSm, t) ?? mediumSm,
      mediumBase: TextStyle.lerp(mediumBase, other.mediumBase, t) ?? mediumBase,
      medium3xl: TextStyle.lerp(medium3xl, other.medium3xl, t) ?? medium3xl,
      semibold2xs:
          TextStyle.lerp(semibold2xs, other.semibold2xs, t) ?? semibold2xs,
      semiboldXs: TextStyle.lerp(semiboldXs, other.semiboldXs, t) ?? semiboldXs,
      semiboldSm: TextStyle.lerp(semiboldSm, other.semiboldSm, t) ?? semiboldSm,
      semiboldBase:
          TextStyle.lerp(semiboldBase, other.semiboldBase, t) ?? semiboldBase,
      semiboldLg: TextStyle.lerp(semiboldLg, other.semiboldLg, t) ?? semiboldLg,
      semibold2xl:
          TextStyle.lerp(semibold2xl, other.semibold2xl, t) ?? semibold2xl,
      boldXs: TextStyle.lerp(boldXs, other.boldXs, t) ?? boldXs,
      boldSm: TextStyle.lerp(boldSm, other.boldSm, t) ?? boldSm,
      boldBase: TextStyle.lerp(boldBase, other.boldBase, t) ?? boldBase,
      boldLg: TextStyle.lerp(boldLg, other.boldLg, t) ?? boldLg,
      boldXl: TextStyle.lerp(boldXl, other.boldXl, t) ?? boldXl,
      bold4xl: TextStyle.lerp(bold4xl, other.bold4xl, t) ?? bold4xl,
    );
  }
}
