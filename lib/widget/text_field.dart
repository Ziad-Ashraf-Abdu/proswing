import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:proswing/core/colors.dart';
import 'package:proswing/core/text_style.dart';

Widget textField({
  required String hintTxt,
  required String image,
  required TextEditingController controller,
  bool isObs = false,
  TextInputType? keyBordType,
  VoidCallback? onIconTap, // Added for toggling visibility
}) {
  return Container(
    height: 70.0,
    padding: const EdgeInsets.symmetric(horizontal: 20.0),
    margin: const EdgeInsets.symmetric(
      horizontal: 20.0,
      vertical: 10.0,
    ),
    decoration: BoxDecoration(
      color: blackTextFild,
      borderRadius: BorderRadius.circular(20.0),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          CrossAxisAlignment.center, // Ensures vertical centering
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textAlignVertical: TextAlignVertical.center,
            obscureText: isObs,
            keyboardType: keyBordType,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hintTxt,
              hintStyle: hintStyle,
              contentPadding: EdgeInsets.symmetric(
                  vertical: 20.0), // Adjust vertical padding
            ),
            style: headline2,
          ),
        ),
        GestureDetector(
          onTap: onIconTap,
          child: SvgPicture.asset(
            'assets/icon/$image',
            height: 24.0, // Adjusted icon height
            width: 24.0, // Consistent width for icon
            color: grayText,
          ),
        ),
      ],
    ),
  );
}