import 'package:flutter/material.dart';

const TextStyle pinTextStyle = TextStyle(
  fontSize: 24,
  color: Colors.white,
);

final ButtonStyle pinButtonStyle = ElevatedButton.styleFrom(
  foregroundColor: Colors.black,
  backgroundColor: Colors.white,
  shape: CircleBorder(),
  padding: EdgeInsets.all(20),
);

const kBackgroundColor = Color(0xFF1A1A1A);
const kDividerColor = Color(0xFF2D2D2D);
const kButtonColor = Color(0xFF00E0FF);
const kTextColor = Color(0xFFAFAFAF);
const kBorderColor = Color(0xFFD0D0D0);

const kButtonStyle = TextStyle(
  color: Color(0xFF313131),
  fontSize: 15,
  fontFamily: 'Inter',
  fontWeight: FontWeight.w500,
);

const kHeaderStyle = TextStyle(
  color: Color(0xFFD1D5DB),
  fontSize: 22,
  fontFamily: 'Inter',
  fontWeight: FontWeight.w500,
);

const kSummaryTextStyle = TextStyle(
  color: kTextColor,
  fontSize: 16,
  fontFamily: 'Inter',
  fontWeight: FontWeight.w500,
);

const kTotalTextStyle = TextStyle(
  color: kTextColor,
  fontSize: 22,
  fontFamily: 'Inter',
  fontWeight: FontWeight.w500,
);
